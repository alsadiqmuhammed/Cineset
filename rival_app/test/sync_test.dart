import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/store.dart';
import 'package:rival_clinic/sync.dart';

/// قاعدة بيانات بالذاكرة تتصرف مثل Firestore: الكتابة تطلع باللقطة فوراً.
class FakeBackend implements SyncBackend {
  final docs = <String, Map<String, String>>{};
  final files = <String, List<int>>{};
  final _streams = <String, StreamController<RemoteSnapshot>>{};
  bool offline = false;

  String _key(String s, String k) => '$s/$k';

  StreamController<RemoteSnapshot> _ctl(String key) =>
      _streams.putIfAbsent(key, () => StreamController.broadcast());

  void emit(String s, String k, {bool fromCache = false}) {
    final m = docs[_key(s, k)] ?? {};
    _ctl(_key(s, k)).add(
      RemoteSnapshot([
        for (final e in m.entries) RemoteDoc(e.key, e.value),
      ], fromCache: fromCache),
    );
  }

  @override
  Stream<RemoteSnapshot> watch(String section, String kind) {
    scheduleMicrotask(() => emit(section, kind));
    return _ctl(_key(section, kind)).stream;
  }

  @override
  Future<void> put(
    String section,
    String kind,
    String id,
    String json, {
    String label = '',
  }) async {
    (docs[_key(section, kind)] ??= {})[id] = json;
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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rival_sync');
    await store.init(dir: dir);
    await store.open(Section.dental, reload: true);
    backend = FakeBackend();
    engine = SyncEngine(store, backend);
    store.sync = engine;
    await engine.attach();
    await wait();
  });

  tearDown(() async {
    await engine.detach();
    store.sync = null;
    await dir.delete(recursive: true);
  });

  test('local changes go up with relative photo paths', () async {
    // أول مزامنة ترفع الأطباء ومعلومات العيادة.
    expect(backend.docs['dental/doctors'], hasLength(5));
    expect(backend.docs['dental/meta']!.keys, ['clinic']);

    final p = await store.addPatient('زينب', '0770');
    final src = File('${dir.path}/b.jpg')..writeAsBytesSync([1, 2, 3]);
    final path = await store.importPhoto(src.path);
    p.cases.add(
      CaseRecord(id: 'c1', title: 'فينير', created: 0, before: Photo(path)),
    );
    await store.save();
    await wait();

    final json = backend.docs['dental/patients']![p.id]!;
    expect(json, isNot(contains(dir.path)));
    final name = path.split('/').last;
    expect(json, contains('"@/photos/$name"'));
    expect(backend.files['dental/$name'], [1, 2, 3]);

    // الحذف المحلي ينحذف من القاعدة.
    await store.deletePatient(p);
    await wait();
    expect(backend.docs['dental/patients']!.containsKey(p.id), isFalse);
  });

  test('changes from another device come down, photos included', () async {
    final other = Patient(
      id: 'p9',
      name: 'مريم',
      phone: '',
      created: 5,
      cases: [
        CaseRecord(
          id: 'c9',
          title: 'تبييض',
          created: 5,
          before: const Photo('@/photos/remote.jpg'),
        ),
      ],
    );
    backend.files['dental/remote.jpg'] = [7, 7];
    await backend.put('dental', 'patients', 'p9', jsonEncode(other));
    await wait();

    final got = store.patients.singleWhere((p) => p.id == 'p9');
    final photo = got.cases.single.before!.path;
    expect(photo, '${store.photosDir.path}/remote.jpg');
    expect(File(photo).readAsBytesSync(), [7, 7]);
    // وانحفظ بملف الجهاز.
    final saved = File('${store.root.path}/patients.json').readAsStringSync();
    expect(saved, contains('مريم'));

    // تعديل من الجهاز الثاني.
    other.name = 'مريم جاسم';
    await backend.put('dental', 'patients', 'p9', jsonEncode(other));
    await wait();
    expect(store.patients.singleWhere((p) => p.id == 'p9').name, 'مريم جاسم');

    // وحذف من الجهاز الثاني.
    await backend.remove('dental', 'patients', 'p9');
    await wait();
    expect(store.patients.where((p) => p.id == 'p9'), isEmpty);
  });

  test('work done offline is kept and uploaded later', () async {
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
    backend.emit('dental', 'patients', fromCache: true);
    await wait();
    expect(store.patients.any((e) => e.id == p.id), isTrue);

    backend.offline = false;
    await engine.push();
    expect(backend.files.keys, contains('dental/${path.split('/').last}'));
    expect(backend.docs['dental/patients']!.containsKey(p.id), isTrue);
  });

  test('a new device merges its data with the clinic database', () async {
    // جهاز ثاني فيه مراجع ما موجود بالقاعدة، والقاعدة بيها مراجع ثاني.
    await engine.detach();
    await store.addPatient('محلي', '1');
    final remote = Patient(id: 'r1', name: 'من القاعدة', phone: '', created: 1);
    backend.docs['dental/patients'] = {'r1': jsonEncode(remote)};
    File('${store.root.path}/sync_state.json').deleteSync();
    await engine.attach();
    await wait();
    final names = store.patients.map((p) => p.name).toSet();
    expect(names, containsAll(['محلي', 'من القاعدة']));
    expect(backend.docs['dental/patients'], hasLength(2));
  });
}
