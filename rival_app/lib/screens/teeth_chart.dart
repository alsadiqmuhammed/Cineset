import 'package:flutter/material.dart';

import '../brand.dart';

/// مخطط الأسنان بترقيم FDI. يمين المراجع على يسار الشاشة (مثل ما يشوفه الطبيب).
class TeethChart extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  const TeethChart({super.key, required this.selected, required this.onToggle});

  static const upper = [
    18,
    17,
    16,
    15,
    14,
    13,
    12,
    11,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
  ];
  static const lower = [
    48,
    47,
    46,
    45,
    44,
    43,
    42,
    41,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
  ];

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    Widget row(List<int> teeth) => Row(
      children: [
        for (var i = 0; i < teeth.length; i++) ...[
          if (i == 8) Container(width: 1.5, height: 30, color: b.line),
          Expanded(
            child: _Tooth(teeth[i], selected.contains(teeth[i]), onToggle),
          ),
        ],
      ],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Text('الفك العلوي', style: TextStyle(color: b.muted, fontSize: 11)),
          const SizedBox(height: 4),
          row(upper),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(color: b.line),
          ),
          row(lower),
          const SizedBox(height: 4),
          Text('الفك السفلي', style: TextStyle(color: b.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Tooth extends StatelessWidget {
  final int n;
  final bool on;
  final ValueChanged<int> onToggle;
  const _Tooth(this.n, this.on, this.onToggle);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return GestureDetector(
      onTap: () => onToggle(n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? b.primary : b.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? b.primary : b.line),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : b.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
