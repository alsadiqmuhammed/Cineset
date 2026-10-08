import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'doctor_edit_screen.dart';
import 'doctor_profile_screen.dart';

class DoctorsScreen extends StatelessWidget {
  /// اختيار "ملفي": يحدد الطبيب اللي يستخدم التطبيق ويرجع.
  final bool pickMe;
  const DoctorsScreen({super.key, this.pickMe = false});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final doctors = store.doctors;
        return Scaffold(
          appBar: AppBar(title: Text(pickMe ? 'منو إنت؟' : 'الأطباء')),
          floatingActionButton: pickMe
              ? null
              : FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorEditScreen()),
                  ),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('طبيب جديد'),
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
                child: TwoToneTitle(
                  pickMe ? 'اختار ملفك' : 'فريق ${b.name}',
                  pickMe
                      ? 'حتى تنسب الحالات إلك'
                      : '${ar(doctors.length)} ${doctors.length == 1 ? 'طبيبة' : 'أطباء'} وابتسامة وحدة',
                ),
              ),
              for (final d in doctors) ...[
                _DoctorTile(
                  doctor: d,
                  active: store.clinic.activeDoctorId == d.id,
                  cases: store.casesOf(d).length,
                  onTap: pickMe
                      ? () async {
                          await store.setActiveDoctor(d);
                          if (context.mounted) Navigator.pop(context);
                        }
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DoctorProfileScreen(doctor: d),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DoctorTile extends StatelessWidget {
  final Doctor doctor;
  final bool active;
  final int cases;
  final VoidCallback onTap;
  const _DoctorTile({
    required this.doctor,
    required this.active,
    required this.cases,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return BrandCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          DoctorAvatar(doctor, size: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: b.text,
                  ),
                ),
                if (doctor.specialty.isNotEmpty)
                  Text(
                    doctor.specialty,
                    style: TextStyle(color: b.muted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (active) Pill('ملفي', bg: b.primary),
              const SizedBox(height: 4),
              Text(
                '${ar(cases)} حالة',
                style: TextStyle(color: b.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
