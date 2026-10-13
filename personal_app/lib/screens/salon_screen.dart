import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/profile.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SalonScreen extends StatelessWidget {
  const SalonScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final open = Salon.isOpen(DateTime.now());
    return SectionPage(
      title: Salon.name,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.spa_outlined, color: kGold, size: 48),
                const SizedBox(height: 8),
                const Text(
                  Salon.name,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(Salon.kind),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (open ? Colors.green : Colors.grey).withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    open ? 'مفتوح هسه' : 'مسدود هسه',
                    style: TextStyle(
                      color: open ? Colors.greenAccent : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionHeader('المعلومات', icon: Icons.info_outline),
        const ItemTile(
          Item('الموقع', Salon.address, Icons.location_on_outlined),
        ),
        const ItemTile(
          Item('الدوام', 'يومياً من 9 الصبح لـ 9 بالليل', Icons.schedule),
        ),
        const SectionHeader('تواصل', icon: Icons.call_outlined),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _open(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(Salon.mapsQuery)}',
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('الخريطة'),
            ),
            if (Salon.phone.isNotEmpty) ...[
              FilledButton.tonalIcon(
                onPressed: () => _open('tel:+${Salon.phone}'),
                icon: const Icon(Icons.call),
                label: const Text('اتصال'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _open('https://wa.me/${Salon.phone}'),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('واتساب'),
              ),
            ],
            if (Salon.instagram.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: () =>
                    _open('https://instagram.com/${Salon.instagram}'),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('انستغرام'),
              ),
          ],
        ),
      ],
    );
  }
}
