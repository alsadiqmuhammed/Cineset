import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../theme.dart';

class SectionPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SectionPage({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: children,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  final IconData? icon;
  const SectionHeader(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: kGold, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: kGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ItemTile extends StatelessWidget {
  final Item item;
  const ItemTile(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: kRed.withValues(alpha: 0.15),
            child: Icon(item.icon, color: kRed),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle),
        ),
      ),
    );
  }
}

List<Widget> groupWidgets(List<Group> groups) => [
  for (final g in groups) ...[
    SectionHeader(g.title, icon: g.icon),
    for (final i in g.items) ItemTile(i),
  ],
];
