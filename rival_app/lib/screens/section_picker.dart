import 'package:flutter/material.dart';

import '../brand.dart';
import 'common.dart';

/// أول شاشة: الطبيب يختار القسم. كل قسم بهويته وأرشيفه المستقل.
class SectionPicker extends StatelessWidget {
  final ValueChanged<Section> onChosen;
  final bool busy;

  /// الأقسام اللي يگدر الحساب يفتحها.
  final List<Section> allowed;
  const SectionPicker({
    super.key,
    required this.onChosen,
    this.busy = false,
    this.allowed = Section.values,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                Text(
                  'أهلاً بيك',
                  style: TextStyle(
                    color: b.muted,
                    fontSize: 17,
                    fontFamily: kFontAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختار القسم',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: b.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'كل قسم إله أرشيفه وأطباؤه وهويته. تگدر تبدّل بعدين من "المزيد".',
                  style: TextStyle(color: b.muted, height: 1.6),
                ),
                const SizedBox(height: 26),
                if (allowed.contains(Section.dental))
                  _SectionCard(
                    brand: dental,
                    title: 'قسم الأسنان',
                    subtitle: 'عيادة ريڤال · تجميل وتقويم وزراعة الأسنان',
                    logo: dental.logoPrimary,
                    light: true,
                    onTap: busy ? null : () => onChosen(Section.dental),
                  ),
                const SizedBox(height: 18),
                if (allowed.contains(Section.beauty))
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
    final page = context.brand;
    final fg = light ? page.text : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: light ? page.bg : null,
        gradient: light ? null : brand.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: page.raised(0.9),
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
                  Image.asset(
                    light && page.isDark ? brand.logoReversed : logo,
                    height: 120,
                  ),
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
