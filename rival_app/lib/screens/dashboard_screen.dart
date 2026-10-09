import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import 'case_screen.dart';
import '../main.dart' show RivalApp;
import 'appointments_screen.dart';
import 'common.dart';
import 'doctor_profile_screen.dart';
import 'doctors_screen.dart';
import 'overlays_screen.dart';
import 'patient_screen.dart';
import 'patients_screen.dart';
import 'schedule.dart';

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
      birthDate: r.birthDate,
    );
    r.applyTo(p);
    await Store.instance.save();
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
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todays = upcoming
            .where(
              (e) =>
                  dayOf(e.$2.nextVisit!) == dayOf(now.millisecondsSinceEpoch),
            )
            .toList();
        final nowMs = now.millisecondsSinceEpoch;
        bool timedMs(int ms) {
          final d = DateTime.fromMillisecondsSinceEpoch(ms);
          return d.hour != 0 || d.minute != 0;
        }

        final nextUp = upcoming
            .where(
              (e) => timedMs(e.$2.nextVisit!)
                  ? e.$2.nextVisit! >= nowMs
                  : dayOf(e.$2.nextVisit!) >= dayOf(nowMs),
            )
            .firstOrNull;
        final births = upcomingBirthdays(store, days: 7);
        final billed = all.allOfDoctor
            .where((e) => e.$2.status == CaseStatus.active)
            .fold(0, (s, e) => s + (e.$2.price ?? 0));
        final paid = all.allOfDoctor
            .where((e) => e.$2.status == CaseStatus.active)
            .fold(0, (s, e) => s + e.$2.paid);
        final (ringValue, ringNote) = billed > 0
            ? (
                paid / billed,
                'محصّل ${ar((paid * 100 / billed).round().clamp(0, 100))}٪',
              )
            : all.total == 0
            ? (0.0, '')
            : (
                all.done / all.total,
                'منجزة ${ar((all.done * 100 / all.total).round())}٪',
              );
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const AlignmentDirectional(
                  -1,
                  -1.1,
                ).resolve(Directionality.of(context)),
                radius: 1.1,
                colors: [
                  b.accent.withValues(alpha: b.isDark ? 0.10 : 0.30),
                  b.bg.withValues(alpha: 0),
                ],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(b),
                              style: TextStyle(
                                fontFamily: kFontAccent,
                                fontSize: 20,
                                height: 1.25,
                                color: b.isDark
                                    ? b.accent
                                    : (b.feminine
                                          ? b.highlight
                                          : b.primaryDeep),
                              ),
                            ),
                            Text(
                              doc?.name ??
                                  b.f(
                                    'اختار ملفك الشخصي',
                                    'اختاري ملفج الشخصي',
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: b.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const ConnectionBadge(),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => doc == null
                                ? const DoctorsScreen(pickMe: true)
                                : DoctorProfileScreen(doctor: doc),
                          ),
                        ),
                        child: Container(
                          width: 52,
                          height: 52,
                          padding: EdgeInsets.all(doc?.photo == null ? 8 : 4),
                          decoration: BoxDecoration(
                            color: b.glass,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: b.raised(0.6),
                          ),
                          child: doc?.photo == null
                              ? Image.asset(b.symbol, fit: BoxFit.contain)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: DoctorAvatar(doc, size: 44),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (RivalApp.of(context).allowedSections.length > 1) ...[
                    const SizedBox(height: 18),
                    const SectionTabs(),
                  ],
                  const SizedBox(height: 18),
                  _SearchField(onTap: () => onGo(1)),
                  const SizedBox(height: 18),
                  _NextCard(
                    nextUp,
                    today: today,
                    onNew: () => _newPatient(context),
                  ),
                  if (births.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (final (p, d) in births.take(2)) ...[
                      BirthdayTile(p, d),
                      const SizedBox(height: 10),
                    ],
                  ],
                  SectionHeader('إجراءات سريعة'),
                  Row(
                    children: [
                      Expanded(
                        child: NeuButton(
                          icon: Icons.person_add_alt_1_outlined,
                          label: b.f('مراجع جديد', 'مراجعة جديدة'),
                          accent: true,
                          onTap: () => _newPatient(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuButton(
                          icon: Icons.event_note_outlined,
                          label: 'المواعيد',
                          tint: b.day.primary,
                          onTap: () => onGo(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuButton(
                          icon: Icons.badge_outlined,
                          label: 'الأطباء',
                          tint: const Color(0xFFB08347),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DoctorsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuButton(
                          icon: Icons.auto_awesome_outlined,
                          label: 'القوالب',
                          tint: b.isDark ? b.accent : b.text,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OverlaysScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  BrandCard(
                    radius: 32,
                    padding: const EdgeInsets.all(20),
                    onTap: () => onGo(3),
                    child: Row(
                      children: [
                        AnimatedRing(
                          value: ringValue,
                          size: 128,
                          stroke: 9,
                          color: b.accent,
                          color2: Color.lerp(b.accent, Colors.brown, 0.18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ar(all.active),
                                style: TextStyle(
                                  fontSize: 30,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: b.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'حالة نشطة',
                                style: TextStyle(fontSize: 11, color: b.muted),
                              ),
                              if (ringNote.isNotEmpty)
                                Text(
                                  ringNote,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: b.isDark
                                        ? b.accent
                                        : const Color(0xFF9B7440),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Figure(
                                'مواعيد اليوم',
                                ar(todays.length),
                                b.isDark ? b.primaryDeep : b.primary,
                              ),
                              const SizedBox(height: 14),
                              _Figure(
                                'واردات الشهر',
                                moneyShort(month.income),
                                b.isDark ? b.accent : const Color(0xFF9B7440),
                              ),
                              const SizedBox(height: 14),
                              _Figure(
                                b.patients,
                                ar(store.patients.length),
                                b.text,
                                small: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (upcoming.where((e) => e != nextUp).isNotEmpty) ...[
                    SectionHeader(
                      'المواعيد القادمة',
                      trailing: TextButton(
                        onPressed: () => onGo(2),
                        child: const Text('الكل'),
                      ),
                    ),
                    for (final (p, c)
                        in upcoming.where((e) => e != nextUp).take(5)) ...[
                      AppointmentTile(p, c),
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
          ),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool small;
  const _Figure(this.label, this.value, this.color, {this.small = false});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: b.muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: TextStyle(
              fontSize: small ? 17 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// خانة بحث (تفتح قائمة المراجعين).
class _SearchField extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: b.glass,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: b.glassEdge),
          boxShadow: b.raised(0.4),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: b.muted, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                b.f('ابحث عن مراجع أو حالة…', 'ابحثي عن مراجعة أو جلسة…'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: b.muted, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة الموعد الجاي الملونة ويا الرسمة اللمّاعة.
class _NextCard extends StatelessWidget {
  final (Patient, CaseRecord)? next;
  final DateTime today;
  final VoidCallback onNew;
  const _NextCard(this.next, {required this.today, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    const ink = Color(0xFFFFF6F0);
    final soft = ink.withValues(alpha: 0.82);
    final e = next;
    String? when, left;
    if (e != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.$2.nextVisit!);
      final timed = d.hour != 0 || d.minute != 0;
      final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
      final mins = d.difference(DateTime.now()).inMinutes;
      left = days == 0 && timed && mins >= 0
          ? (mins < 60
                ? 'بعد ${ar(mins)} دقيقة'
                : 'بعد ${ar(mins ~/ 60)} ساعة${mins % 60 == 0 ? '' : ' و${ar(mins % 60)} د'}')
          : days == 0
          ? 'اليوم'
          : days == 1
          ? 'باچر'
          : 'بعد ${ar(days)} يوم';
      when = [
        days == 0
            ? 'اليوم'
            : days == 1
            ? 'باچر'
            : arDate(e.$2.nextVisit!),
        if (timed) arTime(d),
      ].join(' · ');
    }
    return GestureDetector(
      onTap: e == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaseScreen(patient: e.$1, record: e.$2),
              ),
            ),
      child: Container(
        height: 184,
        decoration: BoxDecoration(
          gradient: b.action,
          borderRadius: BorderRadius.circular(28),
          boxShadow: b.actionShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PositionedDirectional(
              end: -50,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 10,
              top: 16,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.translate(
                  offset: Offset(0, 14 * (1 - v)),
                  child: Opacity(opacity: v.clamp(0, 1), child: child),
                ),
                child: GlossyEmblem(
                  section: b.section,
                  size: 124,
                  onColor: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 150, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e == null ? 'ماكو مواعيد قريبة' : 'الموعد الجاي · $left',
                    style: TextStyle(color: soft, fontSize: 11.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e == null ? b.f('يومك هادئ', 'يومج هادئ') : e.$1.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e == null
                        ? b.f(
                            'سجّل مراجع جديد أو حدد موعد',
                            'سجّلي مراجعة جديدة أو حددي موعد',
                          )
                        : e.$2.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: soft, fontSize: 12.5),
                  ),
                  if (when != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      when,
                      style: const TextStyle(color: ink, fontSize: 12.5),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      if (e == null)
                        _GlassChip('ابدأ', Icons.add, onNew)
                      else if (e.$1.phone.trim().isNotEmpty)
                        _GlassChip(
                          b.f('ذكّره بالواتساب', 'ذكّريها بالواتساب'),
                          Icons.chat_outlined,
                          () => openWhatsApp(
                            e.$1.phone,
                            text: reminderText(b, e.$1, e.$2),
                          ),
                        ),
                    ],
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

class _GlassChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GlassChip(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x33FFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: const BorderSide(color: Color(0x59FFFFFF)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFFFF6F0)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFF6F0),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
