import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'case_screen.dart';
import 'common.dart';
import 'patient_screen.dart' show openWhatsApp, reminderText;

/// كل المواعيد: الفائتة أولاً، وبعدها يوم بيوم، ويا تذكير واتساب جاهز.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  /// null = كل الأيام.
  DateTime? _day;

  static DateTime _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final all = [
          for (final (p, c) in Store.instance.allCases)
            if (c.status == CaseStatus.active && c.nextVisit != null) (p, c),
        ]..sort((a, b) => a.$2.nextVisit!.compareTo(b.$2.nextVisit!));
        final missed = all
            .where((e) => _date(e.$2.nextVisit!).isBefore(today))
            .toList();
        final coming = all
            .where((e) => !_date(e.$2.nextVisit!).isBefore(today))
            .toList();
        final days = [
          for (var i = 0; i < 14; i++) today.add(Duration(days: i)),
        ];
        int countOn(DateTime d) =>
            coming.where((e) => _date(e.$2.nextVisit!) == d).length;
        final shown = _day == null
            ? coming
            : coming.where((e) => _date(e.$2.nextVisit!) == _day).toList();
        final groups = <DateTime, List<(Patient, CaseRecord)>>{};
        for (final e in shown) {
          (groups[_date(e.$2.nextVisit!)] ??= []).add(e);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('المواعيد')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _DayChip(
                      top: 'الكل',
                      bottom: ar(coming.length),
                      selected: _day == null,
                      onTap: () => setState(() => _day = null),
                    ),
                    for (final d in days)
                      _DayChip(
                        top: d == today
                            ? 'اليوم'
                            : d == today.add(const Duration(days: 1))
                            ? 'باچر'
                            : _weekday(d),
                        bottom: ar(d.day),
                        badge: countOn(d),
                        selected: _day == d,
                        onTap: () => setState(() => _day = d),
                      ),
                  ],
                ),
              ),
              if (missed.isNotEmpty && _day == null) ...[
                SectionHeader(
                  'مواعيد فاتت (${ar(missed.length)})',
                  trailing: Text(
                    'سجّل الزيارة أو حدد موعد جديد',
                    style: TextStyle(color: b.muted, fontSize: 11),
                  ),
                ),
                for (final (p, c) in missed) ...[
                  AppointmentTile(p, c),
                  const SizedBox(height: 8),
                ],
              ],
              for (final MapEntry(key: d, value: list) in groups.entries) ...[
                SectionHeader(
                  '${d == today ? 'اليوم · ' : ''}${_weekday(d)} ${arDate(d.millisecondsSinceEpoch)}',
                  trailing: Text(
                    '${ar(list.length)} موعد',
                    style: TextStyle(color: b.muted, fontSize: 12),
                  ),
                ),
                for (final (p, c) in list) ...[
                  AppointmentTile(p, c),
                  const SizedBox(height: 8),
                ],
              ],
              if (shown.isEmpty && (missed.isEmpty || _day != null))
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.event_available,
                    title: 'ماكو مواعيد',
                    body: 'حدد موعد المراجعة القادمة من صفحة الحالة.',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _weekday(DateTime d) => const [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
][d.weekday - 1];

class _DayChip extends StatelessWidget {
  final String top, bottom;
  final int badge;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 6, bottom: 6),
      child: Material(
        color: selected ? b.primary : b.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? b.primary : b.line),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        top,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: selected ? Colors.white70 : b.muted,
                        ),
                      ),
                      Text(
                        bottom,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : b.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge > 0)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : b.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        ar(badge),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: selected ? b.primary : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// موعد: التاريخ والساعة، المراجع والعلاج، كم باقي، وتذكير بالواتساب.
class AppointmentTile extends StatelessWidget {
  final Patient p;
  final CaseRecord c;
  const AppointmentTile(this.p, this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final d = DateTime.fromMillisecondsSinceEpoch(c.nextVisit!);
    final today = DateTime.now();
    final days = DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final late = days < 0;
    final timed = d.hour != 0 || d.minute != 0;
    final when = late
        ? 'فات من ${ar(-days)} يوم'
        : days == 0
        ? (timed ? arTime(d) : 'اليوم')
        : days == 1
        ? 'باچر${timed ? ' ${arTime(d)}' : ''}'
        : 'بعد ${ar(days)} يوم';
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaseScreen(patient: p, record: c),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: late
                  ? const Color(0xFFFDECEA)
                  : b.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  ar(d.day),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: late ? const Color(0xFFB3261E) : b.primary,
                  ),
                ),
                Text(
                  arMonths[d.month - 1],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: b.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: b.text),
                ),
                Text(
                  [
                    c.title,
                    if ((c.due ?? 0) > 0) 'متبقي ${money(c.due!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: b.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Pill(
            when,
            bg: late
                ? const Color(0xFFFDECEA)
                : b.accent.withValues(alpha: 0.35),
            fg: late ? const Color(0xFFB3261E) : b.dark,
          ),
          if (p.phone.trim().isNotEmpty)
            IconButton(
              tooltip: 'ذكّر بالواتساب',
              onPressed: () =>
                  openWhatsApp(p.phone, text: reminderText(b, p, c)),
              icon: Icon(Icons.chat, color: b.primary, size: 20),
            ),
        ],
      ),
    );
  }
}
