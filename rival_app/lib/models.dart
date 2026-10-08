import 'dart:ui';

/// صورة مع نقطتي المحاذاة (بإحداثيات بكسلات الصورة).
/// النقطتان عادةً زاويتا الفم، أو أي نقطتين ثابتتين بنفس المكان بصورتي قبل وبعد.
class Photo {
  final String path;
  final Offset? a, b;
  const Photo(this.path, {this.a, this.b});

  bool get aligned => a != null && b != null;

  Photo withPoints(Offset a, Offset b) => Photo(path, a: a, b: b);

  Map<String, dynamic> toJson() => {
    'path': path,
    if (a != null) 'a': [a!.dx, a!.dy],
    if (b != null) 'b': [b!.dx, b!.dy],
  };

  static Offset? _pt(dynamic v) => v == null
      ? null
      : Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());

  factory Photo.fromJson(Map<String, dynamic> j) =>
      Photo(j['path'] as String, a: _pt(j['a']), b: _pt(j['b']));
}

class CaseRecord {
  final String id;
  String title;
  String note;
  final int created;
  Photo? before, after;

  CaseRecord({
    required this.id,
    required this.title,
    this.note = '',
    required this.created,
    this.before,
    this.after,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'created': created,
    if (before != null) 'before': before!.toJson(),
    if (after != null) 'after': after!.toJson(),
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
  );
}

class Patient {
  final String id;
  String name;
  String phone;
  final int created;
  final List<CaseRecord> cases;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.created,
    List<CaseRecord>? cases,
  }) : cases = cases ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'created': created,
    'cases': [for (final c in cases) c.toJson()],
  };

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: (j['phone'] as String?) ?? '',
    created: j['created'] as int,
    cases: [
      for (final c in (j['cases'] as List? ?? []))
        CaseRecord.fromJson(c as Map<String, dynamic>),
    ],
  );
}
