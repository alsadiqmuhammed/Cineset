import 'dart:io';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../report_pdf.dart';
import '../stats.dart';
import '../store.dart';
import 'case_screen.dart';
import 'common.dart';
import 'doctor_edit_screen.dart';
import 'patient_screen.dart';

/// الملف الشخصي للطبيب: التعريف، التواصل، الإحصائيات، ومعرض حالاته.
class DoctorProfileScreen extends StatelessWidget {
  final Doctor doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        if (!store.doctors.contains(doctor)) return const Scaffold();
        final stats = Stats.of(store, doctorId: doctor.id);
        final isMe = store.clinic.activeDoctorId == doctor.id;
        final gallery = stats.cases
            .where((e) => e.$2.after != null)
            .take(12)
            .toList();
        final treatments = stats.byTreatment.entries.take(6).toList();
        final maxT = treatments.isEmpty ? 0 : treatments.first.value;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 330,
                backgroundColor: b.primaryDeep,
                foregroundColor: Colors.white,
                actions: [
                  if (!store.isDoctorAccount || store.myDoctorId == doctor.id)
                    IconButton(
                      tooltip: 'تعديل',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorEditScreen(doctor: doctor),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  IconButton(
                    tooltip: 'تقرير PDF',
                    onPressed: () => shareReport(
                      context,
                      () => doctorReport(b, doctor, stats),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(gradient: b.heroGradient),
                    child: CustomPaint(
                      painter: RingsPainter(b.accent),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Pill(
                                b.f('طبيبك', 'طبيبتچ'),
                                bg: b.accent,
                                fg: b.dark,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'تعرّف على',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                doctor.name,
                                style: TextStyle(
                                  color: b.accent,
                                  fontFamily: b.feminine
                                      ? kFontAccent
                                      : kFontUi,
                                  fontSize: b.feminine ? 30 : 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: b.accent,
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: DoctorAvatar(doctor, size: 92),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      doctor.specialty,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList.list(
                  children: [
                    if (doctor.services.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in doctor.services)
                            Pill(
                              s,
                              bg: b.primary.withValues(alpha: 0.1),
                              fg: b.primaryDeep,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        if (!store.isDoctorAccount)
                          Expanded(
                            child: isMe
                                ? FilledButton.tonalIcon(
                                    onPressed: () =>
                                        store.setActiveDoctor(null),
                                    icon: const Icon(Icons.verified),
                                    label: const Text('هذا ملفي'),
                                  )
                                : FilledButton.icon(
                                    onPressed: () =>
                                        store.setActiveDoctor(doctor),
                                    icon: const Icon(Icons.how_to_reg),
                                    label: const Text('هذا أنا'),
                                  ),
                          ),
                        if (doctor.phone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => callPhone(doctor.phone),
                            icon: const Icon(Icons.call),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => openWhatsApp(doctor.phone),
                            icon: const Icon(Icons.chat),
                          ),
                        ],
                      ],
                    ),
                    if (doctor.bio.isNotEmpty) ...[
                      SectionHeader('نبذة'),
                      BrandCard(
                        child: Text(
                          doctor.bio,
                          style: TextStyle(color: b.text, height: 1.7),
                        ),
                      ),
                    ],
                    SectionHeader('بالأرقام'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: [
                        StatTile(
                          ar(stats.total),
                          'حالة',
                          Icons.folder_shared_outlined,
                        ),
                        StatTile(
                          ar(stats.patients),
                          b.patients,
                          Icons.people_outline,
                        ),
                        StatTile(
                          ar(stats.done),
                          'مكتملة',
                          Icons.check_circle_outline,
                        ),
                        StatTile(
                          stats.avgDays == null
                              ? '—'
                              : ar(stats.avgDays!.round()),
                          'يوم متوسط العلاج',
                          Icons.timelapse,
                        ),
                      ],
                    ),
                    if (treatments.isNotEmpty) ...[
                      SectionHeader('أكثر العلاجات'),
                      BrandCard(
                        child: Column(
                          children: [
                            for (final t in treatments)
                              BarRow(label: t.key, value: t.value, max: maxT),
                          ],
                        ),
                      ),
                    ],
                    SectionHeader('من حالاته'),
                    if (gallery.isEmpty)
                      Text(
                        'الحالات اللي بيها صورة "بعد" تبين هنا.',
                        style: TextStyle(color: b.muted),
                      )
                    else
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        children: [
                          for (final (p, c) in gallery)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CaseScreen(patient: p, record: c),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  errorBuilder: missingPhoto,
                                  File(c.after!.path),
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const StatTile(this.value, this.label, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: b.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: b.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: b.text,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: b.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
