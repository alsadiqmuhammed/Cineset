import 'dart:ui';

import 'charts.dart' show legacyAreaIds;

/// صورة مع نقطتي المحاذاة (بإحداثيات بكسلات الصورة).
/// للأسنان: زاويتي الفم. للتجميل: العينين. أو أي نقطتين ثابتتين بالصورتين.
class Photo {
  final String path;
  final Offset? a, b;
  final int? taken;
  const Photo(this.path, {this.a, this.b, this.taken});

  bool get aligned => a != null && b != null;

  Photo withPoints(Offset a, Offset b) => Photo(path, a: a, b: b, taken: taken);

  Map<String, dynamic> toJson() => {
    'path': path,
    if (a != null) 'a': [a!.dx, a!.dy],
    if (b != null) 'b': [b!.dx, b!.dy],
    if (taken != null) 'taken': taken,
  };

  static Offset? _pt(dynamic v) => v == null
      ? null
      : Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
    j['path'] as String,
    a: _pt(j['a']),
    b: _pt(j['b']),
    taken: j['taken'] as int?,
  );
}

class Visit {
  final String id;
  int date;
  String note;
  Visit({required this.id, required this.date, this.note = ''});

  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'note': note};
  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
    id: j['id'] as String,
    date: j['date'] as int,
    note: (j['note'] as String?) ?? '',
  );
}

enum CaseStatus {
  active('قيد العلاج'),
  done('مكتملة');

  final String label;
  const CaseStatus(this.label);
}

class CaseRecord {
  final String id;
  String title;
  String note;
  final int created;
  Photo? before, after;
  String? doctorId;
  CaseStatus status;
  int? completed;
  final List<int> teeth; // ترقيم FDI
  final List<String> areas; // مناطق خريطة الوجه (تجميل)
  final Map<String, String>
  doses; // الكمية لكل منطقة، مثلاً "٢٠ وحدة" أو "١ مل"
  final List<Visit> visits;
  int? nextVisit; // موعد المراجعة القادم

  CaseRecord({
    required this.id,
    required this.title,
    this.note = '',
    required this.created,
    this.before,
    this.after,
    this.doctorId,
    this.status = CaseStatus.active,
    this.completed,
    List<int>? teeth,
    List<String>? areas,
    Map<String, String>? doses,
    List<Visit>? visits,
    this.nextVisit,
  }) : teeth = teeth ?? [],
       areas = areas ?? [],
       doses = doses ?? {},
       visits = visits ?? [];

  /// تاريخ آخر زيارة (أو بداية الحالة).
  int get lastActivity => visits.isEmpty
      ? created
      : visits.map((v) => v.date).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'created': created,
    if (before != null) 'before': before!.toJson(),
    if (after != null) 'after': after!.toJson(),
    if (doctorId != null) 'doctorId': doctorId,
    'status': status.name,
    if (completed != null) 'completed': completed,
    'teeth': teeth,
    'areas': areas,
    'doses': doses,
    'visits': [for (final v in visits) v.toJson()],
    if (nextVisit != null) 'nextVisit': nextVisit,
  };

  factory CaseRecord.fromJson(Map<String, dynamic> j) => CaseRecord(
    id: j['id'] as String,
    title: j['title'] as String,
    note: (j['note'] as String?) ?? '',
    created: j['created'] as int,
    before: j['before'] == null
        ? null
        : Photo.fromJson(j['before'] as Map<String, dynamic>),
    after: j['after'] == null
        ? null
        : Photo.fromJson(j['after'] as Map<String, dynamic>),
    doctorId: j['doctorId'] as String?,
    status: CaseStatus.values.asNameMap()[j['status']] ?? CaseStatus.active,
    completed: j['completed'] as int?,
    teeth: [for (final t in (j['teeth'] as List? ?? [])) t as int],
    areas: [
      for (final a in (j['areas'] as List? ?? []))
        legacyAreaIds[a as String] ?? a,
    ],
    doses: {
      for (final e in ((j['doses'] as Map?) ?? {}).entries)
        e.key as String: e.value as String,
    },
    nextVisit: j['nextVisit'] as int?,
    visits: [
      for (final v in (j['visits'] as List? ?? []))
        Visit.fromJson(v as Map<String, dynamic>),
    ],
  );
}

enum Gender {
  male('ذكر'),
  female('أنثى');

  final String label;
  const Gender(this.label);
}

class Patient {
  final String id;
  String name;
  String phone;
  final int created;
  Gender? gender;
  int? birthYear;
  String notes;
  final List<CaseRecord> cases;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.created,
    this.gender,
    this.birthYear,
    this.notes = '',
    List<CaseRecord>? cases,
  }) : cases = cases ?? [];

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'created': created,
    if (gender != null) 'gender': gender!.name,
    if (birthYear != null) 'birthYear': birthYear,
    'notes': notes,
    'cases': [for (final c in cases) c.toJson()],
  };

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: (j['phone'] as String?) ?? '',
    created: j['created'] as int,
    gender: Gender.values.asNameMap()[j['gender']],
    birthYear: j['birthYear'] as int?,
    notes: (j['notes'] as String?) ?? '',
    cases: [
      for (final c in (j['cases'] as List? ?? []))
        CaseRecord.fromJson(c as Map<String, dynamic>),
    ],
  );
}

class Doctor {
  final String id;
  String name;
  String specialty;
  String phone;
  String bio;
  String? photo;
  final List<String> services;

  Doctor({
    required this.id,
    required this.name,
    this.specialty = '',
    this.phone = '',
    this.bio = '',
    this.photo,
    List<String>? services,
  }) : services = services ?? [];

  /// أول حرف من الاسم بدون "د."
  String get initial {
    final n = name.replaceFirst(RegExp(r'^د\.?\s*'), '').trim();
    return n.isEmpty ? '؟' : n.characters.first;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'specialty': specialty,
    'phone': phone,
    'bio': bio,
    if (photo != null) 'photo': photo,
    'services': services,
  };

  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
    id: j['id'] as String,
    name: j['name'] as String,
    specialty: (j['specialty'] as String?) ?? '',
    phone: (j['phone'] as String?) ?? '',
    bio: (j['bio'] as String?) ?? '',
    photo: j['photo'] as String?,
    services: [for (final s in (j['services'] as List? ?? [])) s as String],
  );
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

class ClinicInfo {
  String address;
  String hours;
  List<String> phones;
  String instagram;
  String? activeDoctorId;

  ClinicInfo({
    this.address = '',
    this.hours = '',
    List<String>? phones,
    this.instagram = '',
    this.activeDoctorId,
  }) : phones = phones ?? [];

  Map<String, dynamic> toJson() => {
    'address': address,
    'hours': hours,
    'phones': phones,
    'instagram': instagram,
    if (activeDoctorId != null) 'activeDoctorId': activeDoctorId,
  };

  factory ClinicInfo.fromJson(Map<String, dynamic> j) => ClinicInfo(
    address: (j['address'] as String?) ?? '',
    hours: (j['hours'] as String?) ?? '',
    phones: [for (final p in (j['phones'] as List? ?? [])) p as String],
    instagram: (j['instagram'] as String?) ?? '',
    activeDoctorId: j['activeDoctorId'] as String?,
  );
}
