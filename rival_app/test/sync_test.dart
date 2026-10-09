import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/store.dart';
import 'package:rival_clinic/sync.dart';

class FakeDoc {
  String json;
  Map<String, Object?> fields;
  FakeDoc(this.json, this.fields);
}

class _Watcher {
  final String key;
  final Scope? scope;
  final StreamController<RemoteSnapshot> ctl;
  _Watcher(this.key, this.scope, this.ctl);
}

/// قاعدة بيانات بالذاكرة تتصرف مثل Firestore: الكتابة تطلع باللقطة فوراً،
/// والطبيب يستلم بس الوثائق اللي تطابق شرطه.
class FakeBackend implements SyncBackend {
  final docs = <String, Map<String, FakeDoc>>{};
  final files = <String, List<int>>{};
  final _watchers = <_Watcher>[];
  bool offline = false;

  String _key(String s, String k) => '$s/$k';

  bool _match(FakeDoc d, Scope? scope) {
    if (scope == null) return true;
    final v = d.fields[scope.field];
    return scope.contains
        ? (v is List && v.contains(scope.value))
        : v == scope.value;
  }

  void emit(String s, String k, {bool fromCache = false}) {
    final key = _key(s, k);
    for (final w in _watchers.where((w) => w.key == key)) {
      w.ctl.add(
        RemoteSnapshot([
          for (final e in (docs[key] ?? {}).entries)
            if (_match(e.value, w.scope))
              RemoteDoc(e.key, e.value.json, e.value.fields),
        ], fromCache: fromCache),
      );
    }
  }

  void seed(
    String s,
    String k,
    String id,
    Object data, [
    Map<String, Object?> fields = const {},
  ]) => (docs[_key(s, k)] ??= {})[id] = FakeDoc(jsonEncode(data), {...fields});

  Map<String, FakeDoc> of(String k) => docs['dental/$k'] ?? {};

  @override
  Stream<RemoteSnapshot> watch(String section, String kind, {Scope? scope}) {
    final w = _Watcher(
      _key(section, kind),
      scope,
      StreamController.broadcast(),
    );
    _watchers.add(w);
    scheduleMicrotask(() => emit(section, kind));
    return w.ctl.stream;
  }

  @override
  Future<List<RemoteDoc>> fetch(String section, String kind) async => [
    for (final e in (docs[_key(section, kind)] ?? {}).entries)
      RemoteDoc(e.key, e.value.json, e.value.fields),
  ];

  @override
  Future<void> put(
    String section,
    String kind,
    String id,
    String json, {
    String label = '',
    Map<String, Object?> fields = const {},
  }) async {
    (docs[_key(section, kind)] ??= {})[id] = FakeDoc(json, {...fields});
    emit(section, kind);
  }

  @override
  Future<void> remove(String section, String kind, String id) async {
    docs[_key(section, kind)]?.remove(id);
    emit(section, kind);
  }

  @override
  Future<void> upload(String section, String name, File file) async {
    if (offline) throw const SocketException('offline');
    files['$section/$name'] = file.readAsBytesSync();
  }

  @override
  Future<void> download(String section, String name, File dest) async {
    final b = files['$section/$name'];
    if (b == null) throw StateError('missing');
    await dest.writeAsBytes(b);
  }
}

Future<void> wait() => Future.delayed(const Duration(milliseconds: 700));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late FakeBackend backend;
  late SyncEngine engine;
  final store = Store.instance;

  Future<void> start({String? doctorId, bool account = false}) async {
    if (account) await store.useAccount('u1');
    await store.open(Section.dental, reload: true);
    store.myDoctorId = doctorId;
    engine = SyncEngine(store, backend, doctorId: doctorId);
    store.sync = engine;
    await engine.attach();
    await wait();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rival_sync');
    await store.init(dir: dir);
    backend = FakeBackend();
  });

  tearDown(() async {
    await engine.detach();
    store.sync = null;
    await dir.delete(recursive: true);
  });

  test('each patient and each case is its own doc, photos relative', () async {
    await start();
    // أول مزامنة ترفع الأطباء ومعلومات العيادة.
    expect(backend.of('doctors'), hasLength(5));
    expect(backend.of('meta').keys, ['clinic']);

    final p = await store.addPatient('زينب', '0770');
    final src = File('${dir.path}/b.jpg')..writeAsBytesSync([1, 2, 3]);
    final path = await store.importPhoto(src.path);
    p.cases.add(
      CaseRecord(
        id: 'c1',
        title: 'فينير',
        created: 0,
        doctorId: 'd2',
        before: Photo(path),
      ),
    );
    await store.save();
    await wait();

    final person = backend.of('people')[p.id]!;
    expect(person.json, isNot(contains('فينير')));
    expect(person.fields['doctors'], ['d2']);
    final c = backend.of('cases')['c1']!;
    expect(c.fields, {'doctorId': 'd2', 'patientId': p.id});
    expect(c.json, isNot(contains(dir.path)));
    final name = path.split('/').last;
    expect(c.json, contains('"@/photos/$name"'));
    expect(backend.files['dental/$name'], [1, 2, 3]);

    // حذف الحالة ثم المراجع.
    p.cases.clear();
    await store.save();
    await wait();
    expect(backend.of('cases'), isEmpty);
    await store.deletePatient(p);
    await wait();
    expect(backend.of('people').containsKey(p.id), isFalse);
  });

  test('changes from another device come down, photos included', () async {
    await start();
    // الحالة توصل قبل المراجع.
    final c = CaseRecord(
      id: 'c9',
      title: 'تبييض',
      created: 5,
      doctorId: 'd1',
      before: const Photo('@/photos/remote.jpg'),
    );
    backend.files['dental/remote.jpg'] = [7, 7];
    await backend.put(
      'dental',
      'cases',
      'c9',
      jsonEncode({...c.toJson(), 'patientId': 'p9'}),
      fields: {'doctorId': 'd1', 'patientId': 'p9'},
    );
    await wait();
    final other = Patient(id: 'p9', name: 'مريم', phone: '', created: 5);
    await backend.put(
      'dental',
      'people',
      'p9',
      jsonEncode(other.toJson()..remove('cases')),
      fields: {
        'doctors': ['d1'],
      },
    );
    await wait();

    final got = store.patients.singleWhere((p) => p.id == 'p9');
    final photo = got.cases.single.before!.path;
    expect(photo, '${store.photosDir.path}/remote.jpg');
    expect(File(photo).readAsBytesSync(), [7, 7]);
    final saved = File('${store.root.path}/patients.json').readAsStringSync();
    expect(saved, contains('مريم'));
    expect(saved, contains('تبييض'));

    // تعديل الاسم من الجهاز الثاني ما يمسح الحالات.
    other.name = 'مريم جاسم';
    await backend.put(
      'dental',
      'people',
      'p9',
      jsonEncode(other.toJson()..remove('cases')),
      fields: {
        'doctors': ['d1'],
      },
    );
    await wait();
    final again = store.patients.singleWhere((p) => p.id == 'p9');
    expect(again.name, 'مريم جاسم');
    expect(again.cases.single.title, 'تبييض');

    // وحذف من الجهاز الثاني.
    await backend.remove('dental', 'cases', 'c9');
    await backend.remove('dental', 'people', 'p9');
    await wait();
    expect(store.patients.where((p) => p.id == 'p9'), isEmpty);
  });

  test('a doctor account sees and writes only its own cases', () async {
    // القاعدة بيها مراجع مشترك (حالة لكل طبيب)، ومراجع ثاني لطبيب ثاني.
    final shared = Patient(id: 'p1', name: 'مشترك', phone: '', created: 1);
    final hidden = Patient(id: 'p2', name: 'مخفي', phone: '', created: 2);
    for (final (p, docs) in [
      (shared, ['d1', 'd2']),
      (hidden, ['d2']),
    ]) {
      backend.seed('dental', 'people', p.id, p.toJson()..remove('cases'), {
        'doctors': docs,
      });
    }
    for (final (id, pid, doc) in [
      ('c1', 'p1', 'd1'),
      ('c2', 'p1', 'd2'),
      ('c3', 'p2', 'd2'),
    ]) {
      final c = CaseRecord(id: id, title: id, created: 0, doctorId: doc);
      backend.seed(
        'dental',
        'cases',
        id,
        {...c.toJson(), 'patientId': pid},
        {'doctorId': doc, 'patientId': pid},
      );
    }
    backend.seed('dental', 'doctors', 'd1', Doctor(id: 'd1', name: 'د. علي'));
    await start(doctorId: 'd1', account: true);

    expect(store.patients.map((p) => p.name), ['مشترك']);
    expect(store.patients.single.cases.map((c) => c.id), ['c1']);
    // ما ينزرع أطباء افتراضيين بالحساب، ينزلون من القاعدة.
    expect(store.doctors.map((d) => d.id), ['d1']);
    expect(store.activeDoctor?.id, 'd1');

    // الطبيب يعدل اسم المراجع: d2 يبقى بالصلاحيات.
    store.patients.single.name = 'مشترك ٢';
    final p = await store.addPatient('جديد', '1');
    expect(p.createdBy, 'd1');
    p.cases.add(
      CaseRecord(id: 'c4', title: 'حشوة', created: 0, doctorId: 'd1'),
    );
    await store.save();
    await wait();
    expect(backend.of('people')['p1']!.fields['doctors'], ['d1', 'd2']);
    expect(backend.of('people')['p1']!.json, contains('مشترك ٢'));
    expect(backend.of('people')[p.id]!.fields['doctors'], ['d1']);
    expect(backend.of('cases')['c4']!.fields['doctorId'], 'd1');
    // حالات d2 ما انمست.
    expect(backend.of('cases').keys, containsAll(['c2', 'c3']));

    // الإدارة نقلت حالة الطبيب لطبيب ثاني: تختفي من عنده.
    backend.of('cases')['c1']!.fields['doctorId'] = 'd2';
    backend.emit('dental', 'cases');
    await wait();
    expect(store.patients.singleWhere((e) => e.id == 'p1').cases, isEmpty);
    expect(backend.of('cases').containsKey('c1'), isTrue);
  });

  test('work done offline is kept and uploaded later', () async {
    await start();
    backend.offline = true;
    final p = await store.addPatient('أحمد', '0780');
    final src = File('${dir.path}/a.jpg')..writeAsBytesSync([4]);
    final path = await store.importPhoto(src.path);
    p.cases.add(
      CaseRecord(id: 'c2', title: 'زراعة', created: 0, after: Photo(path)),
    );
    await store.save();
    await wait();
    expect(engine.status, SyncStatus.offline);
    // لقطة من الذاكرة ما تحذف شي محلي.
    backend.emit('dental', 'people', fromCache: true);
    await wait();
    expect(store.patients.any((e) => e.id == p.id), isTrue);

    backend.offline = false;
    await engine.push();
    expect(backend.files.keys, contains('dental/${path.split('/').last}'));
    expect(backend.of('people').containsKey(p.id), isTrue);
    expect(backend.of('cases').containsKey('c2'), isTrue);
    expect(engine.status, SyncStatus.synced);
  });

  test('the first version (one doc per patient) is migrated', () async {
    final old = Patient(
      id: 'p5',
      name: 'قديم',
      phone: '',
      created: 3,
      cases: [CaseRecord(id: 'c5', title: 'تقويم', created: 3, doctorId: 'd1')],
    );
    backend.seed('dental', 'patients', 'p5', old);
    await start(account: true);
    expect(store.patients.single.cases.single.title, 'تقويم');
    expect(backend.of('patients'), isEmpty);
    expect(backend.of('people').keys, ['p5']);
    expect(backend.of('cases')['c5']!.fields['patientId'], 'p5');
  });

  test('a new device merges its data with the clinic database', () async {
    await start();
    await engine.detach();
    await store.addPatient('محلي', '1');
    final remote = Patient(id: 'r1', name: 'من القاعدة', phone: '', created: 1);
    backend.seed('dental', 'people', 'r1', remote.toJson()..remove('cases'), {
      'doctors': <String>[],
    });
    File('${store.root.path}/sync_state.json').deleteSync();
    await engine.attach();
    await wait();
    final names = store.patients.map((p) => p.name).toSet();
    expect(names, containsAll(['محلي', 'من القاعدة']));
    expect(backend.of('people'), hasLength(2));
  });
}
