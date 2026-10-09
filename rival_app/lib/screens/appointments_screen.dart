import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'case_screen.dart';
import 'common.dart';
import 'patient_screen.dart' show openWhatsApp, reminderText;
import 'schedule.dart';

DateTime _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime(d.year, d.month, d.day);
}

bool _timed(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return d.hour != 0 || d.minute != 0;
}

/// مواعيد بنفس اليوم بينها أقل من نص ساعة ولنفس الطبيب.
Color _lateColor(Brand b) =>
    b.isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);

Set<String> appointmentConflicts(List<(Patient, CaseRecord)> list) {
  final out = <String>{};
  final timed = [
    for (final e in list)
      if (_timed(e.$2.nextVisit!)) e,
  ]..sort((a, b) => a.$2.nextVisit!.compareTo(b.$2.nextVisit!));
  for (var i = 0; i < timed.length; i++) {
    for (var j = i + 1; j < timed.length; j++) {
      final a = timed[i].$2, c = timed[j].$2;
      if (c.nextVisit! - a.nextVisit! >= 30 * 60 * 1000) break;
      final same =
          a.doctorId == null || c.doctorId == null || a.doctorId == c.doctorId;
      if (same) out.addAll([a.id, c.id]);
    }
  }
  return out;
}

/// المواعيد بشكل ذكي: اليوم كخط زمني، القادم مقسم، الفائت للمتابعة، وأعياد الميلاد.
class AppointmentsScreen extends StatefulWidget {
  final int initialTab;
  const AppointmentsScreen({super.key, this.initialTab = 0});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late int _tab = widget.initialTab;

  /// null = كل الأيام (بتبويب القادم).
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final all = [
          for (final (p, c) in store.allCases)
            if (c.status == CaseStatus.active && c.nextVisit != null) (p, c),
        ]..sort((a, b) => a.$2.nextVisit!.compareTo(b.$2.nextVisit!));
        final missed = [
          for (final e in all)
            if (_date(e.$2.nextVisit!).isBefore(today)) e,
        ].reversed.toList();
        final todays = [
          for (final e in all)
            if (_date(e.$2.nextVisit!) == today) e,
        ];
        final coming = [
          for (final e in all)
            if (_date(e.$2.nextVisit!).isAfter(today)) e,
        ];
        final weekEnd = today.add(const Duration(days: 7));
        final week = all.where((e) {
          final d = _date(e.$2.nextVisit!);
          return !d.isBefore(today) && d.isBefore(weekEnd);
        }).length;
        final conflicts = appointmentConflicts(
          all.where((e) => !_date(e.$2.nextVisit!).isBefore(today)).toList(),
        );
        final births = upcomingBirthdays(store, days: 60);
        final birthsToday = births.where((e) => e.$2 == 0).length;

        final next = todays
            .where(
              (e) =>
                  _timed(e.$2.nextVisit!) &&
                  e.$2.nextVisit! >= now.millisecondsSinceEpoch,
            )
            .firstOrNull;
        final hint = <(IconData, String, Color)>[
          if (next != null)
            (
              Icons.schedule,
              'الجاي ${_inMinutes(next.$2.nextVisit! - now.millisecondsSinceEpoch)} · ${next.$1.name}',
              b.primaryDeep,
            )
          else if (todays.isEmpty)
            (Icons.wb_sunny_outlined, 'ماكو مواعيد اليوم، يومك هادئ', b.muted)
          else
            (Icons.done_all, 'خلصت مواعيد اليوم المحددة بساعة', b.muted),
          if (conflicts.isNotEmpty)
            (
              Icons.warning_amber_rounded,
              '${ar(conflicts.length)} مواعيد متقاربة بأقل من نص ساعة',
              const Color(0xFFC77700),
            ),
          if (missed.isNotEmpty)
            (
              Icons.history,
              '${ar(missed.length)} موعد فات يحتاج متابعة',
              _lateColor(b),
            ),
          if (birthsToday > 0)
            (
              Icons.cake_outlined,
              birthsToday == 1
                  ? 'أكو عيد ميلاد اليوم'
                  : '${ar(birthsToday)} أعياد ميلاد اليوم',
              b.highlight,
            ),
        ];

        final Widget body = switch (_tab) {
          0 => _TodayView(todays, conflicts, key: const ValueKey(0)),
          1 => _ComingView(
            coming,
            conflicts,
            day: _day,
            today: today,
            tomorrow: tomorrow,
            onDay: (d) => setState(() => _day = d),
            key: const ValueKey(1),
          ),
          2 => _ListView(
            missed,
            const {},
            empty: const EmptyState(
              icon: Icons.verified_outlined,
              title: 'ماكو مواعيد فايتة',
              body: 'كل المراجعين إجوا بمواعيدهم أو انحددلهم موعد جديد.',
            ),
            key: const ValueKey(2),
          ),
          _ => _BirthdaysView(births, key: const ValueKey(3)),
        };

        return Scaffold(
          appBar: AppBar(title: const Text('المواعيد')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              BrandCard(
                radius: 26,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _Count(
                          ar(todays.length),
                          'اليوم',
                          b.isDark ? b.primaryDeep : b.primary,
                        ),
                        _Count(ar(week), 'هذا الأسبوع', b.highlight),
                        _Count(
                          ar(missed.length),
                          'فاتت',
                          missed.isEmpty ? b.muted : _lateColor(b),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final (icon, text, color) in hint)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(icon, size: 16, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              NeuTabs(
                labels: const ['اليوم', 'القادم', 'فاتت', 'أعياد'],
                badges: [todays.length, 0, missed.length, birthsToday],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: body,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _inMinutes(int ms) {
    final m = (ms / 60000).ceil();
    if (m < 1) return 'هسه';
    if (m < 60) return 'بعد ${ar(m)} دقيقة';
    final h = m ~/ 60, r = m % 60;
    return 'بعد ${ar(h)} ساعة${r == 0 ? '' : ' و${ar(r)} دقيقة'}';
  }
}

class _Count extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Count(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11.5, color: b.muted)),
        ],
      ),
    );
  }
}

/// اليوم: خط زمني بالساعات ويا علامة "هسه"، وبعدها اللي بدون ساعة.
class _TodayView extends StatelessWidget {
  final List<(Patient, CaseRecord)> list;
  final Set<String> conflicts;
  const _TodayView(this.list, this.conflicts, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: Icons.event_available,
          title: 'ماكو مواعيد اليوم',
          body: 'حدد موعد المراجعة القادمة من صفحة الحالة أو من تبويب القادم.',
        ),
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final timed = list.where((e) => _timed(e.$2.nextVisit!)).toList();
    final untimed = list.where((e) => !_timed(e.$2.nextVisit!)).toList();
    final rows = <Widget>[];
    var nowShown = false;
    for (var i = 0; i < timed.length; i++) {
      final (p, c) = timed[i];
      if (!nowShown && c.nextVisit! >= now) {
        nowShown = true;
        rows.add(_NowLine(color: b.primary));
      }
      rows.add(
        _TimelineRow(
          time: DateTime.fromMillisecondsSinceEpoch(c.nextVisit!),
          past: c.nextVisit! < now,
          last: i == timed.length - 1 && untimed.isEmpty,
          child: AppointmentTile(
            p,
            c,
            conflict: conflicts.contains(c.id),
            compact: true,
          ),
        ),
      );
    }
    if (!nowShown && timed.isNotEmpty) rows.add(_NowLine(color: b.primary));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (untimed.isNotEmpty) ...[
          SectionHeader('اليوم بدون ساعة (${ar(untimed.length)})'),
          for (final (p, c) in untimed) ...[
            AppointmentTile(p, c, compact: true),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final DateTime time;
  final bool past, last;
  final Widget child;
  const _TimelineRow({
    required this.time,
    required this.past,
    required this.last,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  Text(
                    '${ar(h)}:${ar(time.minute).padLeft(2, '٠')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: past ? b.muted : b.text,
                    ),
                  ),
                  Text(
                    time.hour < 12 ? 'ص' : 'م',
                    style: TextStyle(fontSize: 10, color: b.muted),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: past ? b.bg : b.primary,
                    border: Border.all(
                      color: past ? b.muted.withValues(alpha: 0.5) : b.primary,
                      width: 2,
                    ),
                    boxShadow: past
                        ? null
                        : [
                            BoxShadow(
                              color: b.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: last
                        ? Colors.transparent
                        : b.line.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: past ? 0.7 : 1,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  final Color color;
  const _NowLine({required this.color});

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              'هسه',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 4.5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Container(
              height: 1.6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            arTime(DateTime(2000, 1, 1, t.hour, t.minute)),
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

/// القادم: شريط أيام ومقسم (باچر / هذا الأسبوع / بعدين).
class _ComingView extends StatelessWidget {
  final List<(Patient, CaseRecord)> list;
  final Set<String> conflicts;
  final DateTime? day;
  final DateTime today, tomorrow;
  final ValueChanged<DateTime?> onDay;
  const _ComingView(
    this.list,
    this.conflicts, {
    super.key,
    required this.day,
    required this.today,
    required this.tomorrow,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final days = [for (var i = 1; i <= 14; i++) today.add(Duration(days: i))];
    int countOn(DateTime d) =>
        list.where((e) => _date(e.$2.nextVisit!) == d).length;
    final weekEnd = today.add(const Duration(days: 7));
    final shown = day == null
        ? list
        : list.where((e) => _date(e.$2.nextVisit!) == day).toList();
    final groups = <String, List<(Patient, CaseRecord)>>{};
    for (final e in shown) {
      final d = _date(e.$2.nextVisit!);
      final key = day != null
          ? '${_weekday(d)} ${arDate(d.millisecondsSinceEpoch)}'
          : d == tomorrow
          ? 'باچر · ${_weekday(d)}'
          : d.isBefore(weekEnd)
          ? 'هذا الأسبوع'
          : d.month == today.month && d.year == today.year
          ? 'باقي الشهر'
          : 'بعدين';
      (groups[key] ??= []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _DayChip(
                top: 'الكل',
                bottom: ar(list.length),
                selected: day == null,
                onTap: () => onDay(null),
              ),
              for (final d in days)
                _DayChip(
                  top: d == tomorrow ? 'باچر' : _weekday(d),
                  bottom: ar(d.day),
                  badge: countOn(d),
                  selected: day == d,
                  onTap: () => onDay(d),
                ),
            ],
          ),
        ),
        for (final MapEntry(key: title, value: items) in groups.entries) ...[
          SectionHeader(
            title,
            trailing: Text(
              '${ar(items.length)} موعد',
              style: TextStyle(color: b.muted, fontSize: 12),
            ),
          ),
          for (final (p, c) in items) ...[
            AppointmentTile(p, c, conflict: conflicts.contains(c.id)),
            const SizedBox(height: 10),
          ],
        ],
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.event_available,
              title: 'ماكو مواعيد',
              body: 'حدد موعد المراجعة القادمة من صفحة الحالة.',
            ),
          ),
      ],
    );
  }
}

class _ListView extends StatelessWidget {
  final List<(Patient, CaseRecord)> list;
  final Set<String> conflicts;
  final Widget empty;
  const _ListView(this.list, this.conflicts, {super.key, required this.empty});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Padding(padding: const EdgeInsets.only(top: 24), child: empty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (p, c) in list) ...[
          AppointmentTile(p, c, conflict: conflicts.contains(c.id)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BirthdaysView extends StatelessWidget {
  final List<(Patient, int)> list;
  const _BirthdaysView(this.list, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: Icons.cake_outlined,
          title: 'ماكو أعياد ميلاد قريبة',
          body: b.f(
            'أضف تاريخ ميلاد المراجع من "تعديل البيانات" حتى يذكّرك التطبيق ويجهزلك التهنئة.',
            'أضيفي تاريخ ميلاد المراجعة من "تعديل البيانات" حتى يذكّرج التطبيق ويجهزلج التهنئة.',
          ),
        ),
      );
    }
    final soon = list.where((e) => e.$2 <= 7).toList();
    final later = list.where((e) => e.$2 > 7).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (soon.isNotEmpty) ...[
          const SectionHeader('هذا الأسبوع'),
          for (final (p, d) in soon) ...[
            BirthdayTile(p, d),
            const SizedBox(height: 10),
          ],
        ],
        if (later.isNotEmpty) ...[
          const SectionHeader('خلال الشهرين الجايات'),
          for (final (p, d) in later) ...[
            BirthdayTile(p, d),
            const SizedBox(height: 10),
          ],
        ],
      ],
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
      padding: const EdgeInsetsDirectional.only(end: 10, top: 6, bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 60,
          decoration: BoxDecoration(
            color: selected ? null : b.glass,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [b.primary, b.primaryDeep],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: b.raised(selected ? 0.45 : 0.3),
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
                  bottom: 6,
                  start: 0,
                  end: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < (badge > 3 ? 3 : badge); i++)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : b.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// موعد: التاريخ والساعة، المراجع والعلاج، كم باقي، وإجراءات سريعة.
class AppointmentTile extends StatelessWidget {
  final Patient p;
  final CaseRecord c;
  final bool conflict;

  /// بالخط الزمني: الساعة مكتوبة يم الخط، فما نعيد التاريخ.
  final bool compact;
  const AppointmentTile(
    this.p,
    this.c, {
    super.key,
    this.conflict = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final lateBg = _lateColor(b);
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
        : timed
        ? arTime(d)
        : 'بعد ${ar(days)} يوم';
    final store = Store.instance;
    final doctor = store.doctors.length > 1 && !store.isDoctorAccount
        ? store.doctors.where((x) => x.id == c.doctorId).firstOrNull
        : null;
    return BrandCard(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
      topLine: conflict ? const Color(0xFFE09A2B) : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaseScreen(patient: p, record: c),
        ),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                gradient: late ? null : b.pressed,
                color: late ? lateBg.withValues(alpha: 0.1) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    ar(d.day),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: late ? lateBg : b.primaryDeep,
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
          ],
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
                    if (doctor != null) doctor.name,
                    if ((c.due ?? 0) > 0) 'متبقي ${money(c.due!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: b.muted, fontSize: 12),
                ),
                if (!compact || conflict || late) const SizedBox(height: 5),
                if (!compact || conflict || late)
                  Row(
                    children: [
                      if (!compact || late)
                        Flexible(
                          child: Pill(
                            when,
                            bg: late
                                ? lateBg.withValues(alpha: 0.1)
                                : b.accent.withValues(
                                    alpha: b.isDark ? 0.2 : 0.35,
                                  ),
                            fg: late ? lateBg : (b.isDark ? b.accent : b.dark),
                          ),
                        ),
                      if (conflict) ...[
                        if (!compact) const SizedBox(width: 6),
                        const Pill(
                          'متقارب',
                          icon: Icons.warning_amber_rounded,
                          bg: Color(0x22E09A2B),
                          fg: Color(0xFFC77700),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          if (p.phone.trim().isNotEmpty)
            IconButton(
              tooltip: 'ذكّر بالواتساب',
              onPressed: () =>
                  openWhatsApp(p.phone, text: reminderText(b, p, c)),
              icon: const Icon(
                Icons.chat_outlined,
                color: Color(0xFF2E7D4F),
                size: 21,
              ),
            ),
          IconButton(
            tooltip: 'إجراءات',
            onPressed: () => showAppointmentActions(context, p, c),
            icon: Icon(Icons.more_vert, color: b.muted, size: 21),
          ),
        ],
      ),
    );
  }
}
