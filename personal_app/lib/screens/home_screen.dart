import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../theme.dart';
import 'apps_screen.dart';
import 'cine_tools_screen.dart';
import 'gear_screen.dart';
import 'lab_screen.dart';
import 'life_screen.dart';
import 'notes_screen.dart';
import 'salon_screen.dart';
import 'works_screen.dart';

class _Section {
  final String title;
  final IconData icon;
  final Widget Function() page;
  const _Section(this.title, this.icon, this.page);
}

final _sections = [
  _Section('أعمالي', Icons.movie_creation_outlined, () => const WorksScreen()),
  _Section('أدوات التصوير', Icons.wb_twilight, () => const CineToolsScreen()),
  _Section('برتي ليدي', Icons.spa_outlined, () => const SalonScreen()),
  _Section('دفتر الأفكار', Icons.edit_note, () => const NotesScreen()),
  _Section('العدّة', Icons.camera_alt_outlined, () => const GearScreen()),
  _Section('المختبر', Icons.science_outlined, () => const LabScreen()),
  _Section('تطبيقاتي', Icons.apps, () => const AppsScreen()),
  _Section('حياتي وعائلتي', Icons.favorite_border, () => const LifeScreen()),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final open = Salon.isOpen(DateTime.now());
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(salonOpen: open)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [for (final s in _sections) _SectionCard(s)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool salonOpen;
  const _Header({required this.salonOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF3A0A0A), kSurface],
        ),
        border: Border.all(color: kRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: kRed,
                child: Icon(Icons.videocam, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      Profile.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Profile.tagline} · ${Profile.city}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in Profile.roles)
                Chip(
                  label: Text(r, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: kGold.withValues(alpha: 0.4)),
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: salonOpen ? Colors.greenAccent : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${Salon.name}: ${salonOpen ? 'مفتوح هسه' : 'مسدود هسه'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _Section s;
  const _SectionCard(this.s);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => s.page()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(s.icon, color: kRed, size: 30),
              Text(
                s.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
