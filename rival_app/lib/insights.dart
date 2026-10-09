import 'brand.dart';
import 'charts.dart';
import 'models.dart';

/// أرقام الحالة المحسوبة (للتقرير والواجهة).
class CaseFacts {
  final int days;
  final bool done;
  final int visits;
  final int? lastVisit;
  final int? daysSinceLast;
  final int? nextVisit;
  final int? daysToNext;

  const CaseFacts({
    required this.days,
    required this.done,
    required this.visits,
    this.lastVisit,
    this.daysSinceLast,
    this.nextVisit,
    this.daysToNext,
  });

  factory CaseFacts.of(CaseRecord c, {DateTime? now}) {
    final n = (now ?? DateTime.now()).millisecondsSinceEpoch;
    int days(int from, int to) =>
        ((to - from) / 86400000).floor().clamp(0, 100000);
    final done = c.status == CaseStatus.done && c.completed != null;
    final last = c.visits.isEmpty
        ? null
        : c.visits.map((v) => v.date).reduce((a, b) => a > b ? a : b);
    return CaseFacts(
      days: days(c.created, done ? c.completed! : n),
      done: done,
      visits: c.visits.length,
      lastVisit: last,
      daysSinceLast: last == null ? null : days(last, n),
      nextVisit: c.nextVisit,
      // أيام تقويمية: موعد البارحة الساعة ٥ "فات" من اليوم، مو بعد ٢٤ ساعة.
      daysToNext: c.nextVisit == null ? null : daysBetween(n, c.nextVisit!),
    );
  }
}

String _areas(CaseRecord c) => [
  for (final id in c.areas)
    (c.doses[id] ?? '').isEmpty
        ? areaLabel(id)
        : '${areaLabel(id)} (${c.doses[id]})',
].join('، ');

/// ملخص الحالة بجمل واضحة، يتولد من بياناتها.
String caseSummary(
  Brand b,
  Patient p,
  CaseRecord c,
  Doctor? doctor, {
  DateTime? now,
}) {
  final f = CaseFacts.of(c, now: now);
  final who = b.f('للمراجع', 'للمراجعة');
  final kind = b.teethChart ? 'حالة' : 'جلسة';
  final s = StringBuffer('$kind ${c.title} $who ${p.name}');
  if (p.age != null) s.write(' (${ar(p.age!)} سنة)');
  if (doctor != null) s.write(' بإشراف ${doctor.name}');
  s.write('. ');
  s.write('بدأت بتاريخ ${arDate(c.created)}');
  if (f.done) {
    s.write(' واكتملت بتاريخ ${arDate(c.completed!)} خلال ${ar(f.days)} يوم. ');
  } else {
    s.write(
      f.days == 0
          ? ' وهي قيد العلاج. '
          : ' وهي قيد العلاج من ${ar(f.days)} يوم. ',
    );
  }
  if (f.visits > 0) {
    final unit = b.teethChart ? 'زيارة' : 'جلسة';
    s.write(
      'تمت ${ar(f.visits)} $unit، آخرها بتاريخ ${arDate(f.lastVisit!)}. ',
    );
  }
  if (b.teethChart && c.teeth.isNotEmpty) {
    s.write(
      'شمل العلاج ${ar(c.teeth.length)} من الأسنان: ${teethSummary(c.teeth)}. ',
    );
  }
  if (!b.teethChart && c.areas.isNotEmpty) {
    s.write('شملت ${ar(c.areas.length)} من المناطق: ${_areas(c)}. ');
  }
  if (c.before != null && c.after != null) {
    s.write('النتيجة موثّقة بصور قبل وبعد. ');
  } else if (c.before != null) {
    s.write('صورة "قبل" موجودة، وصورة "بعد" بالانتظار. ');
  }
  if (!f.done && f.daysToNext != null) {
    s.write(
      f.daysToNext! >= 0
          ? '${b.f('المراجعة', 'الجلسة')} القادمة بتاريخ ${arDate(f.nextVisit!)}.'
          : 'موعد ${b.f('المراجعة', 'الجلسة')} (${arDate(f.nextVisit!)}) فات بدون تسجيل زيارة.',
    );
  }
  return s.toString().trim();
}

/// تنبيهات مفيدة للطبيب عن الحالة (تطلع بالتقرير وبالواجهة).
List<String> caseAlerts(Brand b, CaseRecord c, {DateTime? now}) {
  final f = CaseFacts.of(c, now: now);
  return [
    if (c.before == null) 'ماكو صورة "قبل" للحالة.',
    if (f.done && c.after == null) 'الحالة مكتملة بدون صورة "بعد".',
    if (!f.done && (f.daysSinceLast ?? f.days) > 60)
      'آخر نشاط قبل ${ar(f.daysSinceLast ?? f.days)} يوم. تحتاج متابعة.',
    if (!f.done && f.daysToNext != null && f.daysToNext! < 0)
      'موعد المراجعة القادمة فات.',
    if (b.teethChart && c.teeth.isEmpty) 'ما تأشرت الأسنان المعالجة.',
    if (!b.teethChart && c.areas.isEmpty) 'ما تأشرت المناطق المعالجة.',
  ];
}
