import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../widgets/common.dart';

class GearScreen extends StatelessWidget {
  const GearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPage(title: 'العدّة', children: groupWidgets(gear));
  }
}
