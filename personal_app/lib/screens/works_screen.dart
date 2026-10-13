import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../widgets/common.dart';

class WorksScreen extends StatelessWidget {
  const WorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      title: 'أعمالي',
      children: [
        const SectionHeader('شغّال عليه هسه', icon: Icons.fiber_manual_record),
        for (final i in currentWork) ItemTile(i),
        const SectionHeader('أفلامي', icon: Icons.local_movies_outlined),
        for (final i in films) ItemTile(i),
        const SectionHeader(
          'حملات وفيديوات للعملاء',
          icon: Icons.campaign_outlined,
        ),
        for (final i in campaigns) ItemTile(i),
      ],
    );
  }
}
