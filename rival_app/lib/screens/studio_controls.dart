import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';

/// مسطرة تمرير مثل برامج تعديل الصور: تسحبها يمين ويسار، والمؤشر ثابت
/// بالنص. ضغطتين ترجعها للصفر.
class RulerSlider extends StatelessWidget {
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final double reset;
  final String Function(double)? format;
  const RulerSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = -1,
    this.max = 1,
    this.reset = 0,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final label =
        format?.call(value) ?? ar((value * 100).round()).replaceAll('-', '−');
    return LayoutBuilder(
      builder: (context, box) {
        // عرض المسطرة كاملة = مرتين عرض الشاشة.
        final span = box.maxWidth * 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            HapticFeedback.selectionClick();
            onChanged(reset);
          },
          onHorizontalDragUpdate: (d) {
            // باتجاه اليمين لليسار: السحب لليسار يزيد القيمة.
            final dir = Directionality.of(context) == TextDirection.rtl
                ? 1
                : -1;
            final v = (value + dir * d.delta.dx / span * (max - min)).clamp(
              min,
              max,
            );
            if ((v - reset).abs() < (max - min) * 0.004 && value != reset) {
              HapticFeedback.selectionClick();
            }
            onChanged(v);
          },
          child: SizedBox(
            height: 58,
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: b.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _RulerPainter(
                      t: (value - min) / (max - min),
                      zero: (reset - min) / (max - min),
                      span: span,
                      tick: b.muted,
                      accent: b.primary,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double t, zero, span;
  final Color tick, accent;
  final bool rtl;
  _RulerPainter({
    required this.t,
    required this.zero,
    required this.span,
    required this.tick,
    required this.accent,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // موضع أي نسبة على الشاشة: القيمة الحالية دايماً بالنص.
    double x(double f) => cx + (rtl ? -1 : 1) * (f - t) * span;
    const n = 80;
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      final px = x(f);
      if (px < -2 || px > size.width + 2) continue;
      final major = i % 10 == 0;
      final fade = 1 - ((px - cx).abs() / cx).clamp(0.0, 1.0) * 0.85;
      canvas.drawLine(
        Offset(px, size.height * (major ? 0.15 : 0.35)),
        Offset(px, size.height * 0.85),
        Paint()
          ..color = tick.withValues(alpha: (major ? 0.9 : 0.5) * fade)
          ..strokeWidth = major ? 2 : 1.2,
      );
    }
    // الصفر نقطة صغيرة.
    final zx = x(zero);
    if (zx >= 0 && zx <= size.width) {
      canvas.drawCircle(
        Offset(zx, size.height * 0.98),
        2.5,
        Paint()..color = tick,
      );
    }
    final p = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);
  }

  @override
  bool shouldRepaint(_RulerPainter o) =>
      o.t != t || o.tick != tick || o.accent != accent || o.span != span;
}

/// قرص صغير بأيقونة وقيمة (يختار أي تعديل تحرّكه المسطرة).
class ValueDial extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value; // -1..1
  final bool selected;
  final VoidCallback onTap;
  const ValueDial({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final changed = value.abs() > 0.004;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CustomPaint(
                painter: _DialPainter(
                  value: value,
                  ring: selected ? b.primary : b.line,
                  arc: b.primary,
                ),
                child: Center(
                  child: changed
                      ? Text(
                          ar((value * 100).round()).replaceAll('-', '−'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? b.primary : b.text,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 21,
                          color: selected ? b.primary : b.text,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? b.text : b.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double value;
  final Color ring, arc;
  _DialPainter({required this.value, required this.ring, required this.arc});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
    if (value.abs() > 0.004) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        value * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.value != value || o.ring != ring || o.arc != arc;
}

/// شريط تبويبات أسفل المحرر.
class EditorTabs extends StatelessWidget {
  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onChanged;
  const EditorTabs({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      padding: EdgeInsets.only(
        top: 6,
        bottom: 6 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: b.card,
        border: Border(top: BorderSide(color: b.line)),
      ),
      child: Row(
        children: [
          for (final (i, (icon, label)) in items.indexed)
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: i == index
                              ? b.primary.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: i == index ? b.primary : b.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == index
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i == index ? b.text : b.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
