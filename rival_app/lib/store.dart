import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// كل البيانات محفوظة داخل مساحة التطبيق الخاصة: ملف JSON للمراجعين،
/// ومجلد للصور، ومجلد للقوالب. ما تظهر بألبوم الكاميرا.
class Store extends ChangeNotifier {
  Store._();
  static final instance = Store._();

  late Directory root;
  final List<Patient> patients = [];
  final List<String> overlays = [];

  Directory get photosDir => Directory('${root.path}/photos');
  Directory get overlaysDir => Directory('${root.path}/overlays');
  Directory get exportsDir => Directory('${root.path}/exports');
  File get _db => File('${root.path}/patients.json');

  Future<void> load({Directory? dir}) async {
    root = dir ?? await getApplicationDocumentsDirectory();
    for (final d in [photosDir, overlaysDir, exportsDir]) {
      await d.create(recursive: true);
    }
    patients.clear();
    if (await _db.exists()) {
      final data = jsonDecode(await _db.readAsString()) as List;
      patients.addAll(data.map((e) => Patient.fromJson(e)));
    }
    overlays
      ..clear()
      ..addAll(
        overlaysDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.png'))
            .map((f) => f.path)
            .toList()
          ..sort(),
      );
    notifyListeners();
  }

  /// يكتب لملف مؤقت ثم يبدّله، حتى ما يتلف الأرشيف إذا انطفى التلفون أثناء الحفظ.
  Future<void> save() async {
    final tmp = File('${_db.path}.tmp');
    await tmp.writeAsString(jsonEncode(patients));
    await tmp.rename(_db.path);
    notifyListeners();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<Patient> addPatient(String name, String phone) async {
    final p = Patient(
      id: newId(),
      name: name,
      phone: phone,
      created: DateTime.now().millisecondsSinceEpoch,
    );
    patients.insert(0, p);
    await save();
    return p;
  }

  Future<void> deletePatient(Patient p) async {
    for (final c in p.cases) {
      _deletePhotos(c);
    }
    patients.remove(p);
    await save();
  }

  Future<void> deleteCase(Patient p, CaseRecord c) async {
    _deletePhotos(c);
    p.cases.remove(c);
    await save();
  }

  void _deletePhotos(CaseRecord c) {
    for (final ph in [c.before, c.after]) {
      if (ph != null) _deleteFile(ph.path);
    }
  }

  void _deleteFile(String path) {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }

  /// ينسخ الصورة لمجلد التطبيق ويرجع مسارها الجديد.
  Future<String> importPhoto(String sourcePath) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    final dest = '${photosDir.path}/${newId()}.$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<void> deletePhoto(Photo old) async {
    _deleteFile(old.path);
  }

  Future<void> addOverlay(String sourcePath) async {
    final dest = '${overlaysDir.path}/${newId()}.png';
    await File(sourcePath).copy(dest);
    overlays.add(dest);
    notifyListeners();
  }

  Future<void> deleteOverlay(String path) async {
    _deleteFile(path);
    overlays.remove(path);
    notifyListeners();
  }

  String exportPath(String ext) => '${exportsDir.path}/rival_${newId()}.$ext';
}
