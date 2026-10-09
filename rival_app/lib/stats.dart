import 'charts.dart' show areaLabel;
import 'models.dart';
import 'store.dart';

enum Period {
  month('هذا الشهر'),
  quarter('آخر ٣ أشهر'),
  year('هذه السنة'),
  all('الكل');

  final String label;
  const Period(this.label);

  DateTime? start(DateTime now) => switch (this) {
    Period.month => DateTime(now.year, now.month),
    Period.quarter => DateTime(now.year, now.month - 2),
    Period.year => DateTime(now.year),
    Period.all => null,
  };
}

/// أرقام الحالات لفترة ولطبيب (اختياري). تستخدمها الرئيسية والتقارير وملف الطبيب.
class Stats {
  final List<(Patient, CaseRecord)> cases;
  final Map<String, String> doctorNames;
  final DateTime? from;

  /// كل حالات الطبيب (بدون حد الفترة)، للمستحقات ودفعات الفترة.
  final List<(Patient, CaseRecord)> allOfDoctor;

  Stats(
    this.cases,
    this.doctorNames, {
    this.from,
    List<(Patient, CaseRecord)>? all,
  }) : allOfDoctor = all ?? cases;

  factory Stats.of(
    Store store, {
    Period period = Period.all,
    String? doctorId,
    DateTime? now,
  }) {
    final from = period.start(now ?? DateTime.now());
    final mine = store.allCases
        .where((e) => doctorId == null || e.$2.doctorId == doctorId)
        .toList();
    final list = mine.where((e) {
      return from == null || e.$2.created >= from.millisecondsSinceEpoch;
    }).toList();
    return Stats(
      list,
      {for (final d in store.doctors) d.id: d.name},
      from: from,
      all: mine,
    );
  }

  // ---------- الحسابات ----------

  /// الدفعات المستلمة بالفترة (حسب تاريخ الدفعة، مو تاريخ الحالة).
  List<(Patient, CaseRecord, Payment)> get payments => [
    for (final (p, c) in allOfDoctor)
      for (final pay in c.payments)
        if (from == null || pay.date >= from!.millisecondsSinceEpoch)
          (p, c, pay),
  ]..sort((a, b) => b.$3.date.compareTo(a.$3.date));

  int get income => payments.fold(0, (s, e) => s + e.$3.amount);

  /// المتبقي بذمة المراجعين الآن (كل الحالات، مو بس الفترة).
  int get outstanding =>
      allOfDoctor.fold(0, (s, e) => s + ((e.$2.due ?? 0) > 0 ? e.$2.due! : 0));

  /// الحالات اللي بذمتها مبلغ، الأكبر أولاً.
  List<(Patient, CaseRecord)> get owing =>
      allOfDoctor.where((e) => (e.$2.due ?? 0) > 0).toList()
        ..sort((a, b) => b.$2.due!.compareTo(a.$2.due!));

  /// قيمة الحالات اللي انفتحت بالفترة (الكلفة المتفق عليها).
  int get billed => cases.fold(0, (s, e) => s + (e.$2.price ?? 0));

  Map<String, int> get incomeByDoctor {
    final m = <String, int>{};
    for (final (_, c, pay) in payments) {
      final k = doctorNames[c.doctorId] ?? 'بدون طبيب';
      m[k] = (m[k] ?? 0) + pay.amount;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// واردات آخر [months] شهر (الأقدم أولاً): (السنة، الشهر، المبلغ).
  List<(int, int, int)> monthlyIncome(int months, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return [
      for (var i = months - 1; i >= 0; i--)
        () {
          final d = DateTime(n.year, n.month - i);
          var sum = 0;
          for (final (_, c) in allOfDoctor) {
            for (final pay in c.payments) {
              final t = DateTime.fromMillisecondsSinceEpoch(pay.date);
              if (t.year == d.year && t.month == d.month) sum += pay.amount;
            }
          }
          return (d.year, d.month, sum);
        }(),
    ];
  }

  int get total => cases.length;
  int get patients => {for (final e in cases) e.$1.id}.length;
  int get active => cases.where((e) => e.$2.status == CaseStatus.active).length;
  int get done => cases.where((e) => e.$2.status == CaseStatus.done).length;
  int get withBeforeAfter =>
      cases.where((e) => e.$2.before != null && e.$2.after != null).length;
  int get visits => cases.fold(0, (n, e) => n + e.$2.visits.length);

  /// متوسط أيام العلاج للحالات المكتملة.
  double? get avgDays {
    final d = [
      for (final e in cases)
        if (e.$2.status == CaseStatus.done && e.$2.completed != null)
          (e.$2.completed! - e.$2.created) / 86400000,
    ];
    return d.isEmpty ? null : d.reduce((a, b) => a + b) / d.length;
  }

  Map<String, int> _count(Iterable<String> keys) {
    final m = <String, int>{};
    for (final k in keys) {
      m[k] = (m[k] ?? 0) + 1;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Map<String, int> get byTreatment => _count(cases.map((e) => e.$2.title));

  Map<String, int> get byDoctor =>
      _count(cases.map((e) => doctorNames[e.$2.doctorId] ?? 'بدون طبيب'));

  Map<String, int> get byArea =>
      _count([for (final e in cases) ...e.$2.areas.map(areaLabel)]);

  Map<String, int> get byGender =>
      _count([for (final e in cases) e.$1.gender?.label ?? 'غير محدد']);

  /// آخر [months] شهر (الأقدم أولاً): (السنة، الشهر، عدد الحالات الجديدة).
  List<(int, int, int)> monthly(int months, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return [
      for (var i = months - 1; i >= 0; i--)
        () {
          final d = DateTime(n.year, n.month - i);
          final count = cases.where((e) {
            final c = DateTime.fromMillisecondsSinceEpoch(e.$2.created);
            return c.year == d.year && c.month == d.month;
          }).length;
          return (d.year, d.month, count);
        }(),
    ];
  }
}
