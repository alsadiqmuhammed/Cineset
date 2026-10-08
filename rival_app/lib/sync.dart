import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';

import 'models.dart';
import 'store.dart';

/// وثيقة بقاعدة البيانات: رقمها ومحتواها (نص JSON بمسارات نسبية).
class RemoteDoc {
  final String id;
  final String json;
  const RemoteDoc(this.id, this.json);
}

/// لقطة من مجموعة: الوثائق، وهل هي من الذاكرة المحلية (بدون تأكيد السيرفر).
class RemoteSnapshot {
  final List<RemoteDoc> docs;
  final bool fromCache;
  const RemoteSnapshot(this.docs, {this.fromCache = false});
}

/// الطبقة اللي تحچي ويا قاعدة البيانات والتخزين (Firebase، أو وهمية للاختبار).
abstract class SyncBackend {
  Stream<RemoteSnapshot> watch(String section, String kind);
  Future<void> put(
    String section,
    String kind,
    String id,
    String json, {
    String label = '',
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
  denied('الحساب ما عنده صلاحية على بيانات العيادة'),
  error('صار خطأ بالمزامنة');

  final String label;
  const SyncStatus(this.label);
}

const _kinds = ['patients', 'doctors', 'meta'];

/// يزامن قسم مفتوح ويا قاعدة البيانات الموحدة:
/// - أي حفظ محلي ينرفع (المراجعين والأطباء ومعلومات العيادة، وكل وحدة بوثيقة).
/// - أي تعديل من جهاز ثاني ينزل ويتحفظ محلياً.
/// - الصور تنرفع للتخزين مرة وحدة، وتنزل للأجهزة اللي ما عندها.
/// المسارات بالوثائق نسبية (@/photos/...) لأن مجلد التطبيق يختلف من جهاز لجهاز.
class SyncEngine {
  final Store store;
  final SyncBackend backend;
  final void Function(SyncStatus status, [String? detail])? onStatus;

  SyncEngine(this.store, this.backend, {this.onStatus});

  String? _section;
  final List<StreamSubscription<RemoteSnapshot>> _subs = [];

  /// آخر محتوى نعرف إنه موجود بقاعدة البيانات لكل وثيقة.
  final Map<String, Map<String, String>> _seen = {
    for (final k in _kinds) k: {},
  };

  /// الوثائق اللي انرفعت قبل (حتى نعرف الحذف من جهاز ثاني).
  final Map<String, Set<String>> _known = {for (final k in _kinds) k: {}};
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

  String _toRemote(String json) => json.replaceAll('"$_prefix', '"@/');
  String _toLocal(String json) => json.replaceAll('"@/', '"$_prefix');

  static final _ref = RegExp(r'@/photos/([^"\\]+)');

  Map<String, (String, String)> _localDocs(String kind) => switch (kind) {
    'patients' => {
      for (final p in store.patients) p.id: (_toRemote(jsonEncode(p)), p.name),
    },
    'doctors' => {
      for (final d in store.doctors) d.id: (_toRemote(jsonEncode(d)), d.name),
    },
    _ => {'clinic': (_toRemote(jsonEncode(store.clinic)), 'معلومات العيادة')},
  };

  // ---------- التشغيل ----------

  Future<void> attach() async {
    await detach();
    final s = store.section.name;
    _section = s;
    for (final k in _kinds) {
      _seen[k]!.clear();
      _known[k]!.clear();
    }
    _uploaded.clear();
    if (await _stateFile.exists()) {
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
    for (final k in _kinds) {
      _subs.add(
        backend
            .watch(s, k)
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

  Future<void> _onRemote(String s, String kind, RemoteSnapshot snap) async {
    if (s != _section) return;
    final seen = _seen[kind]!;
    final known = _known[kind]!;
    final local = _localDocs(kind);
    var changed = false;
    final remoteIds = <String>{};
    for (final d in snap.docs) {
      remoteIds.add(d.id);
      seen[d.id] = d.json;
      known.add(d.id);
      if (local[d.id]?.$1 == d.json) continue;
      _apply(kind, d.id, d.json);
      changed = true;
    }
    // المحذوف من جهاز ثاني: كان عدنا بالسيرفر وهسه ماكو (بس من لقطة مؤكدة).
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
    }
    if (changed) await store.persistFromSync();
    await _downloadMissing(s);
    if (!snap.fromCache) _set(SyncStatus.synced);
    // أي شي محلي ما موجود بالسيرفر (انضاف بدون إنترنت) ينرفع.
    schedulePush();
  }

  void _apply(String kind, String id, String json) {
    final data = jsonDecode(_toLocal(json)) as Map<String, dynamic>;
    switch (kind) {
      case 'patients':
        final p = Patient.fromJson(data);
        final i = store.patients.indexWhere((e) => e.id == id);
        if (i < 0) {
          store.patients.add(p);
          store.patients.sort((a, b) => b.created.compareTo(a.created));
        } else {
          store.patients[i] = p;
        }
      case 'doctors':
        final d = Doctor.fromJson(data);
        final i = store.doctors.indexWhere((e) => e.id == id);
        i < 0 ? store.doctors.add(d) : store.doctors[i] = d;
      default:
        store.clinic = ClinicInfo.fromJson(data);
    }
  }

  void _removeLocal(String kind, String id) {
    switch (kind) {
      case 'patients':
        store.patients.removeWhere((p) => p.id == id);
      case 'doctors':
        store.doctors.removeWhere((d) => d.id == id);
    }
  }

  Future<void> _downloadMissing(String s) async {
    final names = <String>{};
    for (final k in _kinds) {
      for (final (json, _) in _localDocs(k).values) {
        names.addAll(_ref.allMatches(json).map((m) => m[1]!));
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
        final seen = _seen[k]!;
        final known = _known[k]!;
        for (final MapEntry(key: id, value: (json, label)) in local.entries) {
          refs.addAll(_ref.allMatches(json).map((m) => m[1]!));
          if (seen[id] == json) continue;
          seen[id] = json;
          known.add(id);
          // ما ننتظر تأكيد السيرفر: بدون إنترنت ينحفظ بالطابور ويرتفع بعدين.
          unawaited(
            backend
                .put(s, k, id, json, label: label)
                .catchError((Object e) => _set(SyncStatus.error, '$e')),
          );
        }
        for (final id in known.toList()) {
          if (local.containsKey(id)) continue;
          known.remove(id);
          seen.remove(id);
          unawaited(
            backend
                .remove(s, k, id)
                .catchError((Object e) => _set(SyncStatus.error, '$e')),
          );
        }
      }
      var offline = false;
      for (final n in refs) {
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
      if (offline) _set(SyncStatus.offline);
    } finally {
      _pushing = false;
      if (_again) {
        _again = false;
        await push();
      }
    }
  }

  Future<void> _saveState() async {
    if (_section == null) return;
    await _stateFile.writeAsString(
      jsonEncode({
        'known': {for (final k in _kinds) k: _known[k]!.toList()},
        'uploaded': _uploaded.toList(),
      }),
    );
  }
}
