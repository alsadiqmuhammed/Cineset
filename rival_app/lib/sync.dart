import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/painting.dart';

import 'models.dart';
import 'store.dart';

/// وثيقة بقاعدة البيانات: رقمها، محتواها (نص JSON بمسارات نسبية)، وحقول
/// الصلاحيات اللي تقراها قواعد الحماية (doctors / doctorId / patientId).
class RemoteDoc {
  final String id;
  final String json;
  final Map<String, Object?> fields;
  const RemoteDoc(this.id, this.json, [this.fields = const {}]);
}

/// لقطة من مجموعة: الوثائق، وهل هي من الذاكرة المحلية (بدون تأكيد السيرفر).
class RemoteSnapshot {
  final List<RemoteDoc> docs;
  final bool fromCache;
  const RemoteSnapshot(this.docs, {this.fromCache = false});
}

/// شرط على مجموعة: الطبيب يشوف بس وثائقه.
class Scope {
  final String field;
  final String value;

  /// الحقل قائمة (doctors) والشرط "تحتوي"، وإلا "يساوي".
  final bool contains;
  const Scope(this.field, this.value, {this.contains = false});
}

/// الطبقة اللي تحچي ويا قاعدة البيانات والتخزين (Firebase، أو وهمية للاختبار).
abstract class SyncBackend {
  Stream<RemoteSnapshot> watch(String section, String kind, {Scope? scope});
  Future<List<RemoteDoc>> fetch(String section, String kind);
  Future<void> put(
    String section,
    String kind,
    String id,
    String json, {
    String label = '',
    Map<String, Object?> fields = const {},
  });
  Future<void> remove(String section, String kind, String id);
  Future<void> upload(String section, String name, File file);
  Future<void> download(String section, String name, File dest);
}

enum SyncStatus {
  off('بدون مزامنة'),
  syncing('جاري المزامنة...'),
  synced('متزامن'),
  offline('بدون إنترنت، التعديلات تنرفع لما يرجع'),
  denied('الحساب ما عنده صلاحية على هاي البيانات'),
  error('صار خطأ بالمزامنة');

  final String label;
  const SyncStatus(this.label);
}

/// المراجعين (بدون حالاتهم)، الحالات (كل وحدة بوثيقة)، الأطباء، ومعلومات العيادة.
const _kinds = ['people', 'cases', 'doctors', 'meta'];

class _Local {
  final String json;
  final String label;
  final Map<String, Object?> fields;
  const _Local(this.json, this.label, [this.fields = const {}]);

  /// المحتوى والصلاحيات سوا: أي تغيير بيهم يستاهل رفع.
  String get signature => '$json|${jsonEncode(fields)}';
}

/// يزامن قسم مفتوح ويا قاعدة البيانات الموحدة.
///
/// - [doctorId] null = حساب الإدارة (يشوف كل شي). غيرها = طبيب يشوف بس حالاته
///   والمراجعين اللي عنده حالات وياهم، وقواعد الحماية بالسيرفر تفرض نفس الشي.
/// - أي حفظ محلي ينرفع، وأي تعديل من جهاز ثاني ينزل ويتحفظ محلياً.
/// - الصور تنرفع للتخزين مرة وحدة، وتنزل للأجهزة اللي ما عندها.
/// - المسارات بالوثائق نسبية (@/photos/...) لأن مجلد التطبيق يختلف من جهاز لجهاز.
class SyncEngine {
  final Store store;
  final SyncBackend backend;
  final String? doctorId;
  final void Function(SyncStatus status, [String? detail])? onStatus;

  SyncEngine(this.store, this.backend, {this.doctorId, this.onStatus});

  bool get isAdmin => doctorId == null;

  String? _section;
  final List<StreamSubscription<RemoteSnapshot>> _subs = [];

  /// آخر محتوى نعرف إنه موجود بقاعدة البيانات لكل وثيقة.
  final Map<String, Map<String, String>> _seen = {
    for (final k in _kinds) k: {},
  };

  /// الوثائق اللي انرفعت قبل (حتى نعرف الحذف من جهاز ثاني).
  final Map<String, Set<String>> _known = {for (final k in _kinds) k: {}};

  /// المجموعات اللي وصلتنا منها لقطة مؤكدة من السيرفر. قبلها ما نرفع شي،
  /// حتى ما نكتب فوق بيانات أحدث ما نزلت بعد.
  final Set<String> _ready = {};

  /// أطباء كل مراجع مثل ما بالسيرفر (الطبيب ما يشوف حالات غيره، فما يمسحهم).
  final Map<String, Set<String>> _remoteDoctors = {};

  /// حالات وصلت قبل مراجعها.
  final Map<String, Map<String, CaseRecord>> _orphans = {};
  final Set<String> _uploaded = {};
  final Set<String> _downloading = {};
  Timer? _debounce;
  bool _pushing = false, _again = false;
  SyncStatus _status = SyncStatus.off;
  SyncStatus get status => _status;

  File get _stateFile => File('${store.root.path}/sync_state.json');

  void _set(SyncStatus s, [String? detail]) {
    _status = s;
    onStatus?.call(s, detail);
  }

  // ---------- تحويل المسارات ----------

  String get _prefix => '${store.root.path}/';

  // بالويب المسارات تبقى نسبية والصور تنعرض من التخزين مباشرة.
  String _toRemote(String json) =>
      kIsWeb ? json : json.replaceAll('"$_prefix', '"@/');
  String _toLocal(String json) =>
      kIsWeb ? json : json.replaceAll('"@/', '"$_prefix');

  static final _ref = RegExp(r'@/photos/([^"\\]+)');

  /// أطباء المراجع: اللي سجّله واللي عندهم حالات وياه. الطبيب يضيف عليهم
  /// اللي يعرفهم السيرفر، لأنه ما يشوف حالات الباقين.
  List<String> _doctorsOf(Patient p) {
    final ids = <String>{
      ?p.createdBy,
      for (final c in p.cases) ?c.doctorId,
      if (!isAdmin) ...?_remoteDoctors[p.id],
      if (!isAdmin) doctorId!,
    };
    return ids.toList()..sort();
  }

  Map<String, _Local> _localDocs(String kind) {
    switch (kind) {
      case 'people':
        return {
          for (final p in store.patients)
            p.id: _Local(
              _toRemote(jsonEncode(p.toJson()..remove('cases'))),
              p.name,
              {'doctors': _doctorsOf(p)},
            ),
        };
      case 'cases':
        return {
          for (final p in store.patients)
            for (final c in p.cases)
              if (isAdmin || c.doctorId == doctorId)
                c.id: _Local(
                  _toRemote(jsonEncode({...c.toJson(), 'patientId': p.id})),
                  '${p.name} · ${c.title}',
                  {'doctorId': c.doctorId, 'patientId': p.id},
                ),
        };
      case 'doctors':
        return {
          for (final d in store.doctors)
            d.id: _Local(_toRemote(jsonEncode(d)), d.name),
        };
      default:
        return {
          'clinic': _Local(
            _toRemote(jsonEncode(store.clinic)),
            'معلومات العيادة',
          ),
        };
    }
  }

  /// الطبيب يرفع بس اللي تسمحله القواعد: حالاته، ومراجعينه، وملفه.
  bool _mayWrite(String kind, String id) {
    if (isAdmin) return true;
    return switch (kind) {
      'people' || 'cases' => true,
      'doctors' => id == doctorId,
      _ => false,
    };
  }

  bool _mayDelete(String kind, String id) =>
      isAdmin || kind == 'cases' || (kind == 'doctors' && id == doctorId);

  Scope? _scope(String kind) {
    if (isAdmin) return null;
    return switch (kind) {
      'people' => Scope('doctors', doctorId!, contains: true),
      'cases' => Scope('doctorId', doctorId!),
      _ => null,
    };
  }

  // ---------- التشغيل ----------

  Future<void> attach() async {
    await detach();
    final s = store.section.name;
    _section = s;
    for (final k in _kinds) {
      _seen[k]!.clear();
      _known[k]!.clear();
    }
    _ready.clear();
    _remoteDoctors.clear();
    _orphans.clear();
    _uploaded.clear();
    if (!kIsWeb && await _stateFile.exists()) {
      try {
        final j = jsonDecode(await _stateFile.readAsString()) as Map;
        for (final k in _kinds) {
          _known[k]!.addAll(
            ((j['known'] as Map?)?[k] as List? ?? []).cast<String>(),
          );
        }
        _uploaded.addAll((j['uploaded'] as List? ?? []).cast<String>());
      } catch (_) {
        // ملف حالة تالف: نبدأ من جديد، والمقارنة ويا السيرفر تصلّح كل شي.
      }
    }
    _set(SyncStatus.syncing);
    if (isAdmin) await _migrateV1(s);
    for (final k in _kinds) {
      _subs.add(
        backend
            .watch(s, k, scope: _scope(k))
            .listen(
              (snap) => _onRemote(s, k, snap),
              onError: (Object e) => _set(
                '$e'.contains('permission') || '$e'.contains('PERMISSION')
                    ? SyncStatus.denied
                    : SyncStatus.error,
                '$e',
              ),
            ),
      );
    }
  }

  /// النسخة الأولى كانت تحفظ كل مراجع ويا حالاته بوثيقة وحدة (patients).
  /// حساب الإدارة يحوّلها مرة وحدة للترتيب الجديد ويمسح القديم.
  Future<void> _migrateV1(String s) async {
    List<RemoteDoc> old;
    try {
      old = await backend.fetch(s, 'patients');
    } catch (_) {
      return; // بدون إنترنت أو ماكو: نحاول بالمرة الجاية.
    }
    if (old.isEmpty) return;
    var changed = false;
    for (final d in old) {
      if (store.patients.any((p) => p.id == d.id)) continue;
      final data = jsonDecode(_toLocal(d.json)) as Map<String, dynamic>;
      store.patients.add(Patient.fromJson(data));
      changed = true;
    }
    if (changed) {
      store.patients.sort((a, b) => b.created.compareTo(a.created));
      await store.persistFromSync();
    }
    for (final d in old) {
      unawaited(backend.remove(s, 'patients', d.id).catchError((_) {}));
    }
  }

  Future<void> detach() async {
    _debounce?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _section = null;
    _set(SyncStatus.off);
  }

  /// يتنادى بعد كل حفظ محلي. يجمع الحفظات القريبة برفعة وحدة.
  void schedulePush() {
    if (_section == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), push);
  }

  // ---------- التنزيل ----------

  String _sig(RemoteDoc d, String kind) => switch (kind) {
    'people' =>
      '${d.json}|${jsonEncode({'doctors': _listOf(d.fields['doctors'])})}',
    'cases' =>
      '${d.json}|${jsonEncode({'doctorId': d.fields['doctorId'], 'patientId': d.fields['patientId']})}',
    _ => '${d.json}|{}',
  };

  static List<String> _listOf(Object? v) =>
      v is List ? (v.map((e) => '$e').toList()..sort()) : const [];

  Future<void> _onRemote(String s, String kind, RemoteSnapshot snap) async {
    if (s != _section) return;
    final seen = _seen[kind]!;
    final known = _known[kind]!;
    final local = _localDocs(kind);
    var changed = false;
    final remoteIds = <String>{};
    for (final d in snap.docs) {
      remoteIds.add(d.id);
      if (kind == 'people') {
        _remoteDoctors[d.id] = _listOf(d.fields['doctors']).toSet();
      }
      final prev = seen[d.id];
      final mine = local[d.id];
      seen[d.id] = _sig(d, kind);
      known.add(d.id);
      if (mine?.json == d.json) continue;
      // تعديل محلي ما انرفع بعد (مثلاً تأكيد السيرفر لتعديل سابق وصل
      // والطبيب بعده يأشر): ما نكتب فوقه، والرفع الجاي يثبّته.
      if (mine != null && prev != null && mine.signature != prev) continue;
      _apply(kind, d.id, d.json);
      changed = true;
    }
    // المحذوف (أو اللي ما بقى من صلاحية الطبيب): كان عدنا بالسيرفر وهسه
    // ماكو. بس من لقطة مؤكدة، مو من الذاكرة.
    if (!snap.fromCache) {
      for (final id in local.keys) {
        if (remoteIds.contains(id) || !known.contains(id)) continue;
        _removeLocal(kind, id);
        known.remove(id);
        seen.remove(id);
        changed = true;
      }
      for (final id in known.toList()) {
        if (!remoteIds.contains(id) && !local.containsKey(id)) {
          known.remove(id);
          seen.remove(id);
        }
      }
      _ready.add(kind);
    }
    if (changed) await store.persistFromSync();
    await _downloadMissing(s);
    if (_ready.length == _kinds.length && _status != SyncStatus.offline) {
      _set(SyncStatus.synced);
    }
    // أي شي محلي ما موجود بالسيرفر (انضاف بدون إنترنت) ينرفع.
    schedulePush();
  }

  Patient? _patient(String id) {
    for (final p in store.patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _apply(String kind, String id, String json) {
    final data = jsonDecode(_toLocal(json)) as Map<String, dynamic>;
    switch (kind) {
      // الموجود يتحدث بمكانه (assign) حتى الشاشات المفتوحة تبقى على نفس
      // الكائن وتعديلاتها تنحفظ.
      case 'people':
        final fresh = Patient.fromJson({...data, 'cases': const []});
        var p = _patient(id);
        if (p == null) {
          p = fresh;
          store.patients.add(p);
          store.patients.sort((a, b) => b.created.compareTo(a.created));
        } else {
          p.assign(fresh);
        }
        p.cases.addAll(_orphans.remove(id)?.values ?? const []);
        _sortCases(p);
      case 'cases':
        final fresh = CaseRecord.fromJson(data);
        final pid = data['patientId'] as String?;
        CaseRecord? c;
        for (final p in store.patients) {
          final i = p.cases.indexWhere((e) => e.id == id);
          if (i < 0) continue;
          c = p.cases[i];
          // الحالة انتقلت لمراجع ثاني: نشيلها من القديم.
          if (p.id != pid) p.cases.removeAt(i);
        }
        c = (c?..assign(fresh)) ?? fresh;
        final p = pid == null ? null : _patient(pid);
        if (p == null) {
          if (pid != null) (_orphans[pid] ??= {})[id] = c;
          return;
        }
        if (!p.cases.contains(c)) p.cases.add(c);
        _sortCases(p);
      case 'doctors':
        final d = Doctor.fromJson(data);
        final i = store.doctors.indexWhere((e) => e.id == id);
        i < 0 ? store.doctors.add(d) : store.doctors[i].assign(d);
      default:
        store.clinic.assign(ClinicInfo.fromJson(data));
    }
  }

  static void _sortCases(Patient p) =>
      p.cases.sort((a, b) => b.created.compareTo(a.created));

  void _removeLocal(String kind, String id) {
    switch (kind) {
      case 'people':
        store.patients.removeWhere((p) => p.id == id);
      case 'cases':
        for (final p in store.patients) {
          p.cases.removeWhere((c) => c.id == id);
        }
      case 'doctors':
        store.doctors.removeWhere((d) => d.id == id);
    }
  }

  Future<void> _downloadMissing(String s) async {
    if (kIsWeb) return;
    final names = <String>{};
    for (final k in _kinds) {
      for (final l in _localDocs(k).values) {
        names.addAll(_ref.allMatches(l.json).map((m) => m[1]!));
      }
    }
    var got = false;
    for (final n in names) {
      final f = File('${store.photosDir.path}/$n');
      if (f.existsSync() || _downloading.contains(n)) continue;
      _downloading.add(n);
      try {
        await backend.download(s, n, f);
        _uploaded.add(n);
        FileImage(f).evict();
        got = true;
      } catch (_) {
        // الصورة بعدها ما انرفعت من الجهاز الثاني؛ نحاول بالمزامنة الجاية.
      } finally {
        _downloading.remove(n);
      }
    }
    if (got) store.refresh();
  }

  // ---------- الرفع ----------

  Future<void> push() async {
    final s = _section;
    if (s == null) return;
    if (_pushing) {
      _again = true;
      return;
    }
    _pushing = true;
    try {
      final refs = <String>{};
      for (final k in _kinds) {
        final local = _localDocs(k);
        for (final l in local.values) {
          refs.addAll(_ref.allMatches(l.json).map((m) => m[1]!));
        }
        if (!_ready.contains(k)) continue;
        final seen = _seen[k]!;
        final known = _known[k]!;
        for (final MapEntry(key: id, value: l) in local.entries) {
          if (seen[id] == l.signature || !_mayWrite(k, id)) continue;
          seen[id] = l.signature;
          known.add(id);
          // ما ننتظر تأكيد السيرفر: بدون إنترنت ينحفظ بالطابور ويرتفع بعدين.
          unawaited(
            backend
                .put(s, k, id, l.json, label: l.label, fields: l.fields)
                .catchError((Object e) => _set(SyncStatus.error, '$e')),
          );
        }
        for (final id in known.toList()) {
          if (local.containsKey(id)) continue;
          known.remove(id);
          seen.remove(id);
          if (!_mayDelete(k, id)) continue;
          unawaited(
            backend
                .remove(s, k, id)
                .catchError((Object e) => _set(SyncStatus.error, '$e')),
          );
        }
      }
      var offline = false;
      for (final n in kIsWeb ? const <String>[] : refs) {
        if (_uploaded.contains(n)) continue;
        final f = File('${store.photosDir.path}/$n');
        if (!f.existsSync()) continue;
        try {
          await backend.upload(s, n, f);
          _uploaded.add(n);
        } catch (_) {
          offline = true;
        }
      }
      await _saveState();
      if (offline) {
        _set(SyncStatus.offline);
      } else if (_status == SyncStatus.offline) {
        _set(SyncStatus.synced);
      }
    } finally {
      _pushing = false;
      if (_again) {
        _again = false;
        await push();
      }
    }
  }

  Future<void> _saveState() async {
    if (_section == null || kIsWeb) return;
    await _stateFile.writeAsString(
      jsonEncode({
        'known': {for (final k in _kinds) k: _known[k]!.toList()},
        'uploaded': _uploaded.toList(),
      }),
    );
  }
}
