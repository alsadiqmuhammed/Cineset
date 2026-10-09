import 'package:flutter/material.dart';

import '../brand.dart';
import '../report_pdf.dart';
import '../stats.dart';
import '../store.dart';
import 'case_screen.dart';
import 'common.dart';
import 'doctor_profile_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Period _period = Period.month;
  String? _doctorId;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final s = Stats.of(store, period: _period, doctorId: _doctorId);
        final monthly = Stats.of(store, doctorId: _doctorId).monthly(6);
        return Scaffold(
          appBar: AppBar(
            title: const Text('التقارير'),
            actions: const [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 12),
                child: SectionSwitch(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in Period.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(p.label),
                          selected: _period == p,
                          onSelected: (_) => setState(() => _period = p),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _doctorId,
                decoration: const InputDecoration(
                  labelText: 'الطبيب',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('كل الأطباء'),
                  ),
                  for (final d in store.doctors)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _doctorId = v),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  StatTile(ar(s.total), 'حالة', Icons.folder_shared_outlined),
                  StatTile(ar(s.patients), b.patients, Icons.people_outline),
                  StatTile(ar(s.active), 'قيد العلاج', Icons.timelapse),
                  StatTile(ar(s.done), 'مكتملة', Icons.check_circle_outline),
                  StatTile(
                    ar(s.withBeforeAfter),
                    'بيها قبل وبعد',
                    Icons.compare,
                  ),
                  StatTile(
                    ar(s.visits),
                    b.teethChart ? 'زيارة' : 'جلسة',
                    Icons.event_available,
                  ),
                ],
              ),
              SectionHeader('الحسابات'),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      money(s.income),
                      'واردات ${_period.label}',
                      Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      money(s.outstanding),
                      'بذمة ${b.patients}',
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BrandCard(
                child: _MonthlyChart(
                  Stats.of(store, doctorId: _doctorId).monthlyIncome(6),
                  format: _short,
                ),
              ),
              if (_doctorId == null && s.incomeByDoctor.length > 1) ...[
                const SizedBox(height: 10),
                BrandCard(
                  child: Column(
                    children: [
                      for (final e in s.incomeByDoctor.entries)
                        BarRow(
                          label: e.key,
                          value: e.value,
                          max: s.incomeByDoctor.values.first,
                          format: money,
                        ),
                    ],
                  ),
                ),
              ],
              if (s.owing.isNotEmpty) ...[
                const SizedBox(height: 10),
                BrandCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (p, c) in s.owing.take(6))
                        ListTile(
                          dense: true,
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${c.title} · دفع ${money(c.paid)} من ${money(c.price!)}',
                            style: TextStyle(color: b.muted, fontSize: 12),
                          ),
                          trailing: Text(
                            money(c.due!),
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CaseScreen(patient: p, record: c),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SectionHeader('الحالات آخر ٦ أشهر'),
              BrandCard(child: _MonthlyChart(monthly)),
              if (s.byTreatment.isNotEmpty) ...[
                SectionHeader(b.teethChart ? 'حسب العلاج' : 'حسب الجلسة'),
                _Bars(s.byTreatment),
              ],
              if (_doctorId == null && s.byDoctor.isNotEmpty) ...[
                SectionHeader('حسب الطبيب'),
                _Bars(s.byDoctor),
              ],
              if (s.byArea.isNotEmpty) ...[
                SectionHeader('حسب المنطقة'),
                _Bars(s.byArea),
              ],
              if (!b.feminine && s.total > 0) ...[
                SectionHeader('حسب الجنس'),
                _Bars(s.byGender),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: s.total == 0
                    ? null
                    : () => shareReport(
                        context,
                        () => clinicReport(
                          b,
                          s,
                          period: _period,
                          doctor: store.doctor(_doctorId),
                        ),
                      ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('تصدير التقرير الكامل PDF'),
              ),
              if (s.total == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'ماكو حالات بهذي الفترة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: b.muted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Bars extends StatelessWidget {
  final Map<String, int> data;
  const _Bars(this.data);

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.take(8).toList();
    final max = entries.isEmpty ? 0 : entries.first.value;
    return BrandCard(
      child: Column(
        children: [
          for (final e in entries)
            BarRow(label: e.key, value: e.value, max: max),
        ],
      ),
    );
  }
}

/// مبلغ مختصر للأعمدة: ١٫٢ م، ٢٥٠ ألف.
String _short(int v) {
  if (v >= 1000000) {
    final m = (v / 100000).round() / 10;
    return '${ar(m % 1 == 0 ? m.toInt() : m).replaceAll('.', '٫')} م';
  }
  if (v >= 1000) return '${ar((v / 1000).round())} ألف';
  return ar(v);
}

class _MonthlyChart extends StatelessWidget {
  final List<(int, int, int)> months;
  final String Function(int)? format;
  const _MonthlyChart(this.months, {this.format});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final max = months.fold(0, (m, e) => e.$3 > m ? e.$3 : m);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, (_, month, count)) in months.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        format?.call(count) ?? ar(count),
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: b.text,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: max == 0 ? 4 : 4 + 106 * count / max,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: i == months.length - 1
                              ? [b.primary, b.primaryDeep]
                              : [
                                  b.accent,
                                  Color.lerp(b.accent, b.primary, 0.3)!,
                                ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      arMonths[month - 1],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: b.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
