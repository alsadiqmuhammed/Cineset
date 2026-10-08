import 'package:flutter/material.dart';

import '../brand.dart';
import 'common.dart';

/// أول شاشة: الطبيب يختار القسم. كل قسم بهويته وأرشيفه المستقل.
class SectionPicker extends StatelessWidget {
  final ValueChanged<Section> onChosen;
  final bool busy;
  const SectionPicker({super.key, required this.onChosen, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            const Text(
              'أهلاً بيك',
              style: TextStyle(color: Color(0xFF6B5F57), fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'اختار القسم',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF231F20),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'كل قسم إله أرشيفه وأطباؤه وهويته. تگدر تبدّل بعدين من "المزيد".',
              style: TextStyle(color: Color(0xFF6B5F57), height: 1.6),
            ),
            const SizedBox(height: 26),
            _SectionCard(
              brand: dental,
              title: 'قسم الأسنان',
              subtitle: 'عيادة ريڤال · تجميل وتقويم وزراعة الأسنان',
              logo: dental.logoPrimary,
              light: true,
              onTap: busy ? null : () => onChosen(Section.dental),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              brand: beauty,
              title: 'قسم التجميل',
              subtitle: 'ريڤال بيوتي · فلر، بوتوكس، نضارة البشرة',
              logo: beauty.logoReversed,
              light: false,
              onTap: busy ? null : () => onChosen(Section.beauty),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Brand brand;
  final String title, subtitle, logo;
  final bool light;
  final VoidCallback? onTap;
  const _SectionCard({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.logo,
    required this.light,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = light ? brand.text : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: light ? Colors.white : null,
        gradient: light ? null : brand.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: brand.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: RingsPainter(brand.accent),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                children: [
                  Image.asset(logo, height: 120),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: fg,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.75),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: light ? brand.primary : brand.accent,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: light ? Colors.white : brand.dark,
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
    );
  }
}
