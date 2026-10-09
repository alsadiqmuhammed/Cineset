import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'brand.dart';
import 'models.dart';
import 'sync.dart';

/// كل البيانات داخل مساحة التطبيق الخاصة، وكل قسم (أسنان / تجميل) بمجلد مستقل:
/// ملف المراجعين، الأطباء، معلومات العيادة، الصور، والقوالب.
/// ما تظهر بألبوم الكاميرا.
/// يضغط مجلدات الأقسام لملف واحد (يشتغل بخيط منفصل).
Future<void> _zip(String root, List<String> sections, String out) async {
  final enc = ZipFileEncoder()..create(out);
  for (final s in sections) {
    final d = Directory('$root/$s');
    if (!await d.exists()) continue;
    await for (final e in d.list(recursive: true)) {
      if (e is! File || e.path.contains('/exports/')) continue;
      if (e.path.endsWith('sync_state.json')) continue;
      final lower = e.path.toLowerCase();
      final packed =
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp');
      await enc.addFile(
        e,
        e.path.substring(root.length + 1),
        packed ? 0 : null,
      );
    }
  }
  await enc.close();
}

class Store extends ChangeNotifier {
  Store._();
  static final instance = Store._();

  /// مجلد التطبيق بالجهاز (الإعدادات العامة هنا).
  late Directory device;

  /// مجلد البيانات: نفس [device] بدون حساب، أو مجلد خاص بكل حساب
  /// (accounts/{uid}) حتى لو طبيبين يستخدمون نفس التلفون ما يشوف واحد بيانات الثاني.
  late Directory base;
  late Section section;
  Section? _opened;
  final List<Patient> patients = [];
  final List<Doctor> doctors = [];
  final List<String> overlays = [];
  ClinicInfo clinic = ClinicInfo();
  bool lockEnabled = false;

  /// المزامنة ويا قاعدة البيانات الموحدة (إذا الحساب مسجل).
  SyncEngine? sync;

  /// اختار يشتغل بدون حساب (بيانات الجهاز بس).
  bool cloudSkipped = false;

  /// الحساب المسجل (null = بيانات الجهاز بدون حساب).
  String? account;

  /// إذا الحساب لطبيب: ملفه بهذا القسم. يشوف ويضيف بس حالاته.
  String? myDoctorId;
  bool get isDoctorAccount => myDoctorId != null;

  Brand get brand => Brand.of(section);
  Directory get root => Directory('${base.path}/${section.name}');
  Directory get photosDir => Directory('${root.path}/photos');
  Directory get overlaysDir => Directory('${root.path}/overlays');
  Directory get exportsDir => Directory('${root.path}/exports');
  File get _db => File('${root.path}/patients.json');
  File get _doctorsFile => File('${root.path}/doctors.json');
  File get _clinicFile => File('${root.path}/clinic.json');
  File get _settingsFile => File('${device.path}/settings.json');

  /// يجهّز المجلد الأساسي ويقرأ الإعدادات العامة (القفل).
  Future<void> init({Directory? dir}) async {
    device = dir ?? await getApplicationDocumentsDirectory();
    base = device;
    account = null;
    myDoctorId = null;
    _opened = null;
    await _migrateV1();
    if (await _settingsFile.exists()) {
      final s = jsonDecode(await _settingsFile.readAsString()) as Map;
      lockEnabled = s['lock'] == true;
      cloudSkipped = s['cloudSkipped'] == true;
    }
  }

  Future<void> _saveSettings() => _settingsFile.writeAsString(
    jsonEncode({'lock': lockEnabled, 'cloudSkipped': cloudSkipped}),
  );

  Future<void> setLock(bool v) async {
    lockEnabled = v;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setCloudSkipped(bool v) async {
    cloudSkipped = v;
    await _saveSettings();
    notifyListeners();
  }

  /// يبدّل مجلد البيانات للحساب (أو يرجع لبيانات الجهاز). القسم ينفتح من جديد.
  Future<void> useAccount(String? uid) async {
    if (uid == account && _opened != null) return;
    account = uid;
    base = uid == null ? device : Directory('${device.path}/accounts/$uid');
    await base.create(recursive: true);
    myDoctorId = null;
    _opened = null;
    patients.clear();
    doctors.clear();
    overlays.clear();
    clinic = ClinicInfo();
  }

  /// النسخة الأولى كانت تحفظ بالمجلد الأساسي مباشرة؛ ننقلها لقسم الأسنان.
  Future<void> _migrateV1() async {
    final old = File('${base.path}/patients.json');
    if (!await old.exists()) return;
    final dest = Directory('${base.path}/${Section.dental.name}');
    await dest.create(recursive: true);
    for (final name in ['photos', 'overlays', 'exports']) {
      final d = Directory('${base.path}/$name');
      if (await d.exists()) await d.rename('${dest.path}/$name');
    }
    final fixed = (await old.readAsString()).replaceAll(
      '${base.path}/photos/',
      '${dest.path}/photos/',
    );
    await File('${dest.path}/patients.json').writeAsString(fixed);
    await old.delete();
  }

  /// يفتح القسم ويقرأ بياناته. إذا هو مفتوح أصلاً ما يعيد القراءة.
  Future<void> open(Section s, {bool reload = false}) async {
    if (!reload && _opened == s) return;
    // فتحتين بنفس الوقت (ضغطتين سريعة) كانت تخلط المراجعين: الثانية تنتظر.
    final busy = _opening;
    if (busy != null) {
      await busy;
      if (!reload && _opened == s) return;
    }
    final done = Completer<void>();
    _opening = done.future;
    try {
      await _open(s);
    } finally {
      _opening = null;
      done.complete();
    }
  }

  Future<void>? _opening;

  /// أكو قسم مفتوح (حتى نعرف أي هوية نستخدم).
  bool get opened => _opened != null;

  Future<void> _open(Section s) async {
    // مزامنة القسم القديم توقف قبل ما نبدّل القوائم.
    final old = sync;
    sync = null;
    await old?.detach();
    section = s;
    for (final d in [photosDir, overlaysDir, exportsDir]) {
      await d.create(recursive: true);
    }
    // الصور والفيديوهات والتقارير المصدّرة مؤقتة (تنحفظ بالمعرض أو تنشارك).
    final stale = DateTime.now().subtract(const Duration(days: 3));
    try {
      for (final f in exportsDir.listSync().whereType<File>()) {
        if (f.statSync().modified.isBefore(stale)) f.deleteSync();
      }
    } catch (_) {
      // التنظيف مو ضروري.
    }
    patients.clear();
    if (await _db.exists()) {
      final data = jsonDecode(await _db.readAsString()) as List;
      patients.addAll(data.map((e) => Patient.fromJson(e)));
    }
    doctors.clear();
    if (await _doctorsFile.exists()) {
      final data = jsonDecode(await _doctorsFile.readAsString()) as List;
      doctors.addAll(data.map((e) => Doctor.fromJson(e)));
    } else if (account == null) {
      // بالحساب الأطباء ينزلون من قاعدة البيانات، فما نزرع أسماء افتراضية
      // ممكن تنكتب فوق التعديلات.
      doctors.addAll(_seedDoctors(s));
    }
    clinic = await _clinicFile.exists()
        ? ClinicInfo.fromJson(jsonDecode(await _clinicFile.readAsString()))
        : (account == null ? _seedClinic() : ClinicInfo());
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
    await saveAll();
    _opened = s;
  }

  static List<Doctor> _seedDoctors(Section s) => s == Section.dental
      ? [
          Doctor(
            id: 'd1',
            name: 'د. مصطفى عبد الكريم',
            specialty: 'تقويم وتجميل الأسنان',
          ),
          Doctor(
            id: 'd2',
            name: 'د. حنين عبد الكريم',
            specialty: 'قسم التجميل',
          ),
          Doctor(id: 'd3', name: 'د. رباب وليد', specialty: 'أسنان الأطفال'),
          Doctor(id: 'd4', name: 'د. علي جواد', specialty: 'طب الأسنان'),
          Doctor(id: 'd5', name: 'د. ضحى', specialty: 'طب الأسنان'),
        ]
      : [
          Doctor(
            id: 'b1',
            name: 'د. حنين عبد الكريم',
            specialty: 'طبيبة التجميل بعيادة ريڤال بيوتي',
            services: ['فلر', 'بوتوكس', 'نضارة البشرة'],
          ),
        ];

  static ClinicInfo _seedClinic() => ClinicInfo(
    address: 'البصرة، مدخل ياسين خريبط، مقابل جسر العسكري',
    hours: 'يومياً من ٤ العصر لـ ١١ بالليل',
    phones: ['0776 172 0720', '0780 172 0720'],
  );

  /// كل حفظ بملف مؤقت خاص بيه، حتى لو صار حفظين بنفس اللحظة ما يتعارضون.
  Future<void> _write(File f, Object data) async {
    final tmp = File('${f.path}.${newId()}.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename(f.path);
  }

  /// يكتب لملف مؤقت ثم يبدّله، حتى ما يتلف الأرشيف إذا انطفى التلفون أثناء الحفظ.
  Future<void> save() async {
    await _write(_db, patients);
    notifyListeners();
    sync?.schedulePush();
  }

  Future<void> saveAll() async {
    await _write(_db, patients);
    await _write(_doctorsFile, doctors);
    await _write(_clinicFile, clinic);
    notifyListeners();
    sync?.schedulePush();
  }

  Timer? _soon;

  /// حفظ بعد ما يوقف الكتابة شوية (للملاحظات وأي حقل يتغير حرف بحرف).
  void saveSoon() {
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 800), () {
      _soon = null;
      save();
    });
  }

  /// يحفظ الحفظ المؤجل هسه (مثلاً لما التطبيق يروح للخلفية).
  Future<void> flush() async {
    if (_soon == null) return;
    _soon!.cancel();
    _soon = null;
    await save();
  }

  /// يحفظ اللي نزل من قاعدة البيانات (بدون ما يرجع يرفعه).
  Future<void> persistFromSync() async {
    await _write(_db, patients);
    await _write(_doctorsFile, doctors);
    await _write(_clinicFile, clinic);
    notifyListeners();
  }

  /// يعيد رسم الشاشات (مثلاً بعد ما تنزل صورة).
  void refresh() => notifyListeners();

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---------- المراجعين والحالات ----------

  Future<Patient> addPatient(
    String name,
    String phone, {
    Gender? gender,
    int? birthYear,
  }) async {
    final p = Patient(
      id: newId(),
      name: name,
      phone: phone,
      created: DateTime.now().millisecondsSinceEpoch,
      gender: gender ?? (section == Section.beauty ? Gender.female : null),
      birthYear: birthYear,
      createdBy: myDoctorId,
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

  /// كل الحالات مع مراجعها، الأحدث أولاً.
  List<(Patient, CaseRecord)> get allCases => [
    for (final p in patients)
      for (final c in p.cases) (p, c),
  ]..sort((x, y) => y.$2.created.compareTo(x.$2.created));

  Patient? patientOf(CaseRecord c) {
    for (final p in patients) {
      if (p.cases.contains(c)) return p;
    }
    return null;
  }

  /// ينسخ الصورة لمجلد التطبيق ويرجع مسارها الجديد.
  Future<String> importPhoto(String sourcePath) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    final dest = '${photosDir.path}/${newId()}.$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<void> deletePhoto(Photo old) async => _deleteFile(old.path);

  // ---------- الأطباء ----------

  Doctor? doctor(String? id) {
    for (final d in doctors) {
      if (d.id == id) return d;
    }
    return null;
  }

  Doctor? get activeDoctor => doctor(myDoctorId ?? clinic.activeDoctorId);

  Future<void> setActiveDoctor(Doctor? d) async {
    clinic.activeDoctorId = d?.id;
    await saveAll();
  }

  Future<Doctor> addDoctor(Doctor d) async {
    doctors.add(d);
    await saveAll();
    return d;
  }

  Future<void> deleteDoctor(Doctor d) async {
    doctors.remove(d);
    for (final f in [d.photo, d.signature, d.stamp]) {
      if (f != null) _deleteFile(f);
    }
    if (clinic.activeDoctorId == d.id) clinic.activeDoctorId = null;
    for (final (_, c) in allCases) {
      if (c.doctorId == d.id) c.doctorId = null;
    }
    await saveAll();
  }

  List<(Patient, CaseRecord)> casesOf(Doctor d) =>
      allCases.where((e) => e.$2.doctorId == d.id).toList();

  // ---------- القوالب ----------

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

  String exportPath(String ext) =>
      '${exportsDir.path}/rival_${section.name}_${newId()}.$ext';

  // ---------- النسخ الاحتياطي ----------

  /// ملف zip بكل بيانات القسمين (بدون الملفات المصدّرة المؤقتة).
  /// يشتغل بخيط ثاني حتى ما تعلگ الشاشة، والصور تنحفظ بدون ضغط (هي مضغوطة أصلاً).
  Future<String> exportBackup() async {
    await flush();
    final stamp = DateTime.now();
    final out =
        '${exportsDir.path}/rival_backup_${stamp.year}-${stamp.month}-${stamp.day}_${stamp.hour}${stamp.minute}.zip';
    final root = base.path;
    final sections = [for (final s in Section.values) s.name];
    await Isolate.run(() => _zip(root, sections, out));
    return out;
  }

  /// يرجّع نسخة احتياطية: يبدّل بيانات القسمين بمحتوى الملف.
  Future<void> restoreBackup(String zipPath) async {
    final archive = ZipDecoder().decodeStream(InputFileStream(zipPath));
    final names = archive.files.map((f) => f.name).toList();
    if (!names.any((n) => n.endsWith('patients.json'))) {
      throw const FormatException('هذا مو ملف نسخة احتياطية مال ريڤال');
    }
    final tmp = Directory('${base.path}/restore_tmp');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await extractArchiveToDisk(archive, tmp.path);
    for (final s in Section.values) {
      final src = Directory('${tmp.path}/${s.name}');
      if (!await src.exists()) continue;
      final dst = Directory('${base.path}/${s.name}');
      if (await dst.exists()) await dst.delete(recursive: true);
      await src.rename(dst.path);
      // المسارات المحفوظة تخص التلفون القديم؛ نصلّحها للمجلد الحالي.
      for (final name in ['patients.json', 'doctors.json']) {
        final f = File('${dst.path}/$name');
        if (!await f.exists()) continue;
        final fixed = (await f.readAsString()).replaceAllMapped(
          RegExp(r'"(/[^"]*?)/' + s.name + r'/(photos|overlays)/'),
          (m) => '"${dst.path}/${m[2]}/',
        );
        await f.writeAsString(fixed);
      }
    }
    await tmp.delete(recursive: true);
    await open(section, reload: true);
  }
}
