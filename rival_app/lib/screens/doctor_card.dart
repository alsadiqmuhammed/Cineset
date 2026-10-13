import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';

const _shortDays = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

/// بطاقة الطبيب: الاسم والاختصاص، حالاته النشطة، مواعيد الأيام الجاية،
/// وصورته المقصوصة (PNG) بارزة بطرف البطاقة.
class DoctorCard extends StatelessWidget {
  final Doctor doctor;

  /// البطاقة الغامقة (ملفي / الطبيب المختار).
  final bool featured;
  final VoidCallback? onTap;
  final ValueChanged<DateTime>? onDay;
  const DoctorCard({
    super.key,
    required this.doctor,
    this.featured = false,
    this.onTap,
    this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final store = Store.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 0; i < 6; i++) today.add(Duration(days: i))];
    final mine = [
      for (final (_, c) in store.allCases)
        if (c.doctorId == doctor.id) c,
    ];
    final active = mine.where((c) => c.status == CaseStatus.active).length;
    final perDay = <DateTime, int>{};
    for (final c in mine) {
      if (c.status != CaseStatus.active || c.nextVisit == null) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(c.nextVisit!);
      final k = DateTime(d.year, d.month, d.day);
      perDay[k] = (perDay[k] ?? 0) + 1;
    }
    final week = days.fold(0, (s, d) => s + (perDay[d] ?? 0));

    final ink = featured ? const Color(0xFFFFF6F0) : b.text;
    final soft = featured ? const Color(0xB3FFF6F0) : b.muted;
    final bg = featured
        ? (b.section == Section.dental
              ? const Color(0xFF2A2425)
              : const Color(0xFF3A0712))
        : b.glass;
    final portrait = doctor.portrait;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 214,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: featured ? const Color(0x14FFFFFF) : b.glassEdge,
          ),
          boxShadow: featured
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A0A05)
                        .withValues(alpha: b.isDark ? 0.5 : 0.28),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ]
              : b.raised(0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ضوء ناعم ورا الصورة.
            PositionedDirectional(
              end: -30,
              top: -20,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (featured ? b.accent : b.day.primary).withValues(
                        alpha: featured ? 0.22 : 0.10,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 6,
              top: 8,
              bottom: 40,
              width: 150,
              child: portrait != null
                  ? StoredImage(
                      portrait,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: featured ? b.accent : b.glassEdge,
                            width: 2,
                          ),
                        ),
                        child: DoctorAvatar(doctor, size: 92),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 150, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(
                        icon: Icons.folder_open_rounded,
                        text: '${ar(active)} نشطة',
                        featured: featured,
                        color: b.accent,
                      ),
                      if (store.clinic.activeDoctorId == doctor.id)
                        _Tag(
                          icon: Icons.verified_rounded,
                          text: 'ملفي',
                          featured: featured,
                          color: const Color(0xFF2E9E5B),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doctor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (doctor.specialty.isNotEmpty)
                    Text(
                      doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: soft, fontSize: 12.5),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    week == 0
                        ? 'ماكو مواعيد هالأيام'
                        : '${ar(week)} ${week == 1 ? 'موعد' : 'مواعيد'} بالأيام الجاية',
                    style: TextStyle(
                      color: ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // شريط الأيام يغطي أسفل الصورة بنعومة.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 84,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 1)],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              height: 58,
              child: Row(
                children: [
                  for (var i = 0; i < days.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _DayPill(
                        day: days[i],
                        count: perDay[days[i]] ?? 0,
                        on: i == 0,
                        featured: featured,
                        onTap: onDay == null ? null : () => onDay!(days[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool featured;
  final Color color;
  const _Tag({
    required this.icon,
    required this.text,
    required this.featured,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: featured ? const Color(0x1FFFFFFF) : b.glass,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: featured ? const Color(0x24FFFFFF) : b.glassEdge,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: featured ? const Color(0xFFFFF6F0) : b.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final DateTime day;
  final int count;
  final bool on, featured;
  final VoidCallback? onTap;
  const _DayPill({
    required this.day,
    required this.count,
    required this.on,
    required this.featured,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    // اليوم: معبّى بلون غامق (أو فاتح على البطاقة الغامقة).
    final Color bg = on
        ? (featured
              ? const Color(0xFFFFF6F0)
              : (b.isDark ? b.accent : const Color(0xFF231F20)))
        : (featured
              ? const Color(0x1AFFFFFF)
              : (b.isDark ? const Color(0x14FFFFFF) : const Color(0xF2FFFFFF)));
    final Color onFg = on
        ? (featured || b.isDark
              ? const Color(0xFF231F20)
              : const Color(0xFFFFF6F0))
        : (featured ? const Color(0xFFFFF6F0) : b.text);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: featured ? const Color(0x1FFFFFFF) : b.glassEdge,
          ),
          boxShadow: on || featured ? null : b.raised(0.25),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _shortDays[day.weekday - 1],
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 9.5,
                color: onFg.withValues(alpha: 0.75),
              ),
            ),
            Text(
              ar(day.day),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: onFg,
                height: 1.2,
              ),
            ),
            SizedBox(
              height: 6,
              child: count == 0
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < (count > 3 ? 3 : count); i++)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: on ? onFg : b.day.primary,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
