import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import 'case_screen.dart';
import 'common.dart';
import 'doctor_profile_screen.dart';
import 'doctors_screen.dart';
import 'overlays_screen.dart';
import 'patient_screen.dart';
import 'patients_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onGo;
  const DashboardScreen({super.key, required this.onGo});

  String _greeting(Brand b) {
    final h = DateTime.now().hour;
    return h < 12 ? 'صباح الخير' : 'مساء الخير';
  }

  Future<void> _newPatient(BuildContext context) async {
    final r = await showPatientDialog(context);
    if (r == null || !context.mounted) return;
    final p = await Store.instance.addPatient(
      r.name,
      r.phone,
      gender: r.gender,
      birthYear: r.birthYear,
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientScreen(patient: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final doc = store.activeDoctor;
        final month = Stats.of(store, period: Period.month);
        final all = Stats.of(store);
        final active = store.allCases
            .where((e) => e.$2.status == CaseStatus.active)
            .take(8)
            .toList();
        final recent = store.allCases.take(5).toList();
        final soon = DateTime.now()
            .add(const Duration(days: 14))
            .millisecondsSinceEpoch;
        final upcoming =
            store.allCases
                .where(
                  (e) =>
                      e.$2.status == CaseStatus.active &&
                      e.$2.nextVisit != null &&
                      e.$2.nextVisit! <= soon,
                )
                .toList()
              ..sort((a, b) => a.$2.nextVisit!.compareTo(b.$2.nextVisit!));
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Image.asset(
                          b.logoHorizontal,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SectionSwitch(),
                  ],
                ),
                const SizedBox(height: 16),
                HeroPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: doc == null
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DoctorsScreen(pickMe: true),
                                    ),
                                  )
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DoctorProfileScreen(doctor: doc),
                                    ),
                                  ),
                            borderRadius: BorderRadius.circular(40),
                            child: DoctorAvatar(doc, size: 54),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(b),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  doc?.name ?? 'اختار ملفك الشخصي',
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Pill(b.name, bg: b.accent, fg: b.dark),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          _HeroStat(ar(month.total), 'حالة هذا الشهر'),
                          _HeroStat(ar(all.active), 'قيد العلاج'),
                          _HeroStat(ar(store.patients.length), b.patients),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                  children: [
                    _Action(
                      Icons.person_add_alt_1,
                      b.newPatient,
                      () => _newPatient(context),
                      primary: true,
                    ),
                    _Action(Icons.insights, 'التقارير', () => onGo(2)),
                    _Action(
                      Icons.badge_outlined,
                      'الأطباء',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DoctorsScreen(),
                        ),
                      ),
                    ),
                    _Action(
                      Icons.filter_frames_outlined,
                      'القوالب',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OverlaysScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (upcoming.isNotEmpty) ...[
                  SectionHeader('المواعيد القادمة'),
                  for (final (p, c) in upcoming.take(6)) ...[
                    _AppointmentTile(p, c),
                    const SizedBox(height: 8),
                  ],
                ],
                if (active.isNotEmpty) ...[
                  SectionHeader(
                    'قيد العلاج',
                    trailing: TextButton(
                      onPressed: () => onGo(1),
                      child: const Text('الكل'),
                    ),
                  ),
                  SizedBox(
                    height: 214,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: active.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _ActiveCard(active[i]),
                    ),
                  ),
                ],
                SectionHeader('آخر الحالات'),
                if (recent.isEmpty)
                  BrandCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          color: b.primary,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.f(
                            'ابدأ بإضافة أول مراجع وصوّر قبل العلاج.',
                            'ابدئي بإضافة أول مراجعة وصوّري قبل الجلسة.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: b.muted),
                        ),
                      ],
                    ),
                  )
                else
                  for (final e in recent) ...[
                    CaseTile(patient: e.$1, record: e.$2, showPatient: true),
                    const SizedBox(height: 10),
                  ],
                SectionHeader('العيادة'),
                BrandCard(
                  child: Column(
                    children: [
                      _InfoLine(Icons.schedule, store.clinic.hours),
                      const Divider(height: 20),
                      _InfoLine(
                        Icons.location_on_outlined,
                        store.clinic.address,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  const _HeroStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: b.accent,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _Action(this.icon, this.label, this.onTap, {this.primary = false});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary ? b.primary : b.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: primary ? Colors.white : b.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: b.text,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final (Patient, CaseRecord) e;
  const _ActiveCard(this.e);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final (p, c) = e;
    return SizedBox(
      width: 150,
      child: BrandCard(
        padding: const EdgeInsets.all(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaseScreen(patient: p, record: c),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoThumb(c.after?.path ?? c.before?.path, c.title, size: 128),
            const SizedBox(height: 8),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: b.text),
            ),
            Text(
              c.title,
              maxLines: 1,
              style: TextStyle(color: b.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Row(
      children: [
        Icon(icon, color: b.accent == b.highlight ? b.primary : b.highlight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: b.text)),
        ),
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final Patient p;
  final CaseRecord c;
  const _AppointmentTile(this.p, this.c);

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
    final when = late
        ? 'فات من ${ar(-days)} يوم'
        : days == 0
        ? 'اليوم'
        : days == 1
        ? 'باچر'
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
                  style: TextStyle(fontWeight: FontWeight.w800, color: b.text),
                ),
                Text(c.title, style: TextStyle(color: b.muted, fontSize: 12)),
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
          if (p.phone.isNotEmpty)
            IconButton(
              tooltip: 'واتساب',
              onPressed: () => openWhatsApp(p.phone),
              icon: Icon(Icons.chat, color: b.primary, size: 20),
            ),
        ],
      ),
    );
  }
}
