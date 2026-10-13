import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../widgets/common.dart';

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      title: 'حياتي وعائلتي',
      children: [
        const SectionHeader('عائلتي', icon: Icons.family_restroom),
        for (final i in family) ItemTile(i),
        ...groupWidgets(life),
      ],
    );
  }
}
