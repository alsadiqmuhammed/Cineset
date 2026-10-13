import 'package:flutter/material.dart';

import '../brand.dart';
import '../store.dart';
import 'appointments_screen.dart';
import 'common.dart';
import 'doctor_card.dart';
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
          floatingActionButton: pickMe || store.isDoctorAccount
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
              for (final (i, d) in doctors.indexed) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 420 + 90 * (i > 6 ? 6 : i)),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: DoctorCard(
                    doctor: d,
                    featured: store.clinic.activeDoctorId == d.id,
                    onDay: pickMe
                        ? null
                        : (_) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AppointmentsScreen(initialTab: 1),
                            ),
                          ),
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
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}
