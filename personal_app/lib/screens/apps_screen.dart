import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../widgets/common.dart';

class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      title: 'تطبيقاتي',
      children: [for (final i in myApps) ItemTile(i)],
    );
  }
}
