import 'package:flutter/material.dart';

import '../theme.dart';
import '../tools/sun.dart';
import '../widgets/common.dart';

class CineToolsScreen extends StatelessWidget {
  const CineToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('أدوات التصوير'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'الشمس'),
              Tab(text: 'أنامورفيك'),
              Tab(text: 'الشتر'),
              Tab(text: 'التخزين'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_SunTab(), _AnamorphicTab(), _ShutterTab(), _StorageTab()],
        ),
      ),
    );
  }
}

String _hm(DateTime? t) => t == null
    ? '—'
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _SunTab extends StatefulWidget {
  const _SunTab();
  @override
  State<_SunTab> createState() => _SunTabState();
}

class _SunTabState extends State<_SunTab> {
  static const _places = {
    'البصرة': (30.5085, 47.7804),
    'شط العرب': (30.55, 47.83),
    'بغداد': (33.3152, 44.3661),
    'أربيل': (36.1911, 44.0091),
  };
  String _place = 'البصرة';
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final (lat, lon) = _places[_place]!;
    final s = sunTimes(_day, lat, lon);
    Widget row(String label, DateTime? a, DateTime? b, Color color) => Card(
      child: ListTile(
        leading: Icon(Icons.wb_twilight, color: color),
        title: Text(label),
        trailing: Text(
          '${_hm(a)} – ${_hm(b)}',
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _place,
                items: [
                  for (final p in _places.keys)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) => setState(() => _place = v!),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('${_day.day}/${_day.month}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (d != null) setState(() => _day = d);
              },
            ),
          ],
        ),
        const SectionHeader('الصبح', icon: Icons.wb_sunny_outlined),
        row('الساعة الزرقاء', s.dawnBlue, s.dawnGolden, Colors.lightBlueAccent),
        const SizedBox(height: 8),
        row('الساعة الذهبية', s.dawnGolden, s.morningGoldenEnd, kGold),
        const SizedBox(height: 8),
        row('الشروق', s.sunrise, s.sunrise, Colors.orangeAccent),
        const SectionHeader('المغرب', icon: Icons.nights_stay_outlined),
        row('الساعة الذهبية', s.eveningGoldenStart, s.duskGolden, kGold),
        const SizedBox(height: 8),
        row('الغروب', s.sunset, s.sunset, Colors.deepOrangeAccent),
        const SizedBox(height: 8),
        row('الساعة الزرقاء', s.duskGolden, s.duskBlue, Colors.lightBlueAccent),
        const SizedBox(height: 16),
        Text(
          'الذهبية: الشمس بين 6° فوق الأفق و4° تحته. الزرقاء: بين 4° و6° تحت الأفق. الأوقات حسب توقيت التلفون.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _AnamorphicTab extends StatefulWidget {
  const _AnamorphicTab();
  @override
  State<_AnamorphicTab> createState() => _AnamorphicTabState();
}

class _AnamorphicTabState extends State<_AnamorphicTab> {
  static const _sensors = {
    '16:9 (UHD)': 16 / 9,
    '17:9 (DCI)': 17 / 9,
    '3:2': 3 / 2,
    '4:3': 4 / 3,
  };
  static const _squeezes = [1.33, 1.5, 1.6, 1.8, 2.0];
  String _sensor = '16:9 (UHD)';
  double _squeeze = 1.6;

  @override
  Widget build(BuildContext context) {
    final out = _sensors[_sensor]! * _squeeze;
    final cropTo239 = out > 2.39
        ? 'قص الجوانب: ${((1 - 2.39 / out) * 100).toStringAsFixed(1)}% من العرض'
        : 'قص فوق وجوّه: ${((1 - out / 2.39) * 100).toStringAsFixed(1)}% من الارتفاع';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('نسبة الكاميرا', icon: Icons.crop),
        Wrap(
          spacing: 8,
          children: [
            for (final k in _sensors.keys)
              ChoiceChip(
                label: Text(k),
                selected: _sensor == k,
                onSelected: (_) => setState(() => _sensor = k),
              ),
          ],
        ),
        const SectionHeader('السكويز', icon: Icons.unfold_less),
        Wrap(
          spacing: 8,
          children: [
            for (final q in _squeezes)
              ChoiceChip(
                label: Text('${q}x${q == 1.6 ? ' (Sirui Venus)' : ''}'),
                selected: _squeeze == q,
                onSelected: (_) => setState(() => _squeeze = q),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('النسبة بعد فك السكويز'),
                Text(
                  '${out.toStringAsFixed(2)}:1',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'للوصول لـ 2.39:1 — $cropTo239',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'بالتايملاين: عرض الكليب × $_squeeze (أو Pixel Aspect Ratio = $_squeeze بـ Resolve)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShutterTab extends StatefulWidget {
  const _ShutterTab();
  @override
  State<_ShutterTab> createState() => _ShutterTabState();
}

class _ShutterTabState extends State<_ShutterTab> {
  static const _fps = <double>[23.976, 24, 25, 30, 48, 50, 60, 100, 120];
  double _f = 25;

  @override
  Widget build(BuildContext context) {
    final denom = (_f * 2).round();
    // الإضاءة على 50Hz ترمش 100 مرة بالثانية، فالشتر لازم يكون مضاعف 1/100.
    final flickerSafe = _f == _f.roundToDouble() && 100 % denom == 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('الفريم ريت', icon: Icons.speed),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _fps)
              ChoiceChip(
                label: Text(
                  f == f.roundToDouble() ? f.toInt().toString() : '$f',
                ),
                selected: _f == f,
                onSelected: (_) => setState(() => _f = f),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('الشتر حسب قاعدة 180°'),
                Text(
                  '1/$denom',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: kGold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              flickerSafe ? Icons.check_circle : Icons.warning_amber,
              color: flickerSafe ? Colors.greenAccent : Colors.orangeAccent,
            ),
            title: const Text('الكهرباء بالعراق 50Hz'),
            subtitle: Text(
              flickerSafe
                  ? 'هذا الفريم ريت آمن من الفليكر ويه الإضاءة العادية.'
                  : 'ممكن يطلع فليكر ويه إضاءة البيوت والمحلات. استخدم شتر 1/50 أو 1/100 (زاوية 172.8° على 24fps) أو صوّر 25/50fps.',
            ),
          ),
        ),
      ],
    );
  }
}

class _StorageTab extends StatefulWidget {
  const _StorageTab();
  @override
  State<_StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<_StorageTab> {
  final _mbps = TextEditingController(text: '240');
  final _minutes = TextEditingController(text: '60');
  final _card = TextEditingController(text: '256');

  @override
  void dispose() {
    _mbps.dispose();
    _minutes.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mbps = double.tryParse(_mbps.text) ?? 0;
    final minutes = double.tryParse(_minutes.text) ?? 0;
    final card = double.tryParse(_card.text) ?? 0;
    final gb = mbps * minutes * 60 / 8 / 1000;
    final cardMinutes = mbps > 0 ? card * 1000 * 8 / mbps / 60 : 0.0;
    Widget field(String label, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        field('البت ريت (Mbps)', _mbps),
        field('مدة التصوير (دقيقة)', _minutes),
        field('حجم الكارت (GB)', _card),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('المساحة المطلوبة'),
                Text(
                  '${gb.toStringAsFixed(1)} GB',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الكارت يكفي تقريباً ${cardMinutes.toStringAsFixed(0)} دقيقة',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'مثال: XAVC S-I 4K 24p بالـ FX3 حوالي 240Mbps. تأكد من البت ريت بقائمة الكاميرا.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
