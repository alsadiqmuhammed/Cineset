import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../video.dart';

/// مسطرة تمرير مثل برامج تعديل الصور: تسحبها يمين ويسار والمؤشر ثابت
/// بالنص، وتكمل تنزلق شوية بعد ما تترك (مثل التمرير الطبيعي) وتوقف بنعومة.
/// ضغطتين ترجعها للصفر.
class RulerSlider extends StatefulWidget {
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
  State<RulerSlider> createState() => _RulerSliderState();
}

class _RulerSliderState extends State<RulerSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fling = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onFling);
  double _span = 1;
  int _lastTick = 0;

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  double get _range => widget.max - widget.min;

  void _emit(double v) {
    final c = v.clamp(widget.min, widget.max);
    // نبضة خفيفة كل عُشر من المسطرة، وعند الصفر.
    final tick = ((c - widget.min) / _range * 20).round();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    widget.onChanged(c);
  }

  void _onFling() {
    final v = _fling.value;
    if (v <= widget.min || v >= widget.max) _fling.stop();
    _emit(v);
  }

  double get _dir => Directionality.of(context) == TextDirection.rtl ? 1 : -1;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final value = widget.value;
    final label =
        widget.format?.call(value) ??
        ar((value * 100).round()).replaceAll('-', '−');
    return LayoutBuilder(
      builder: (context, box) {
        // عرض المسطرة كاملة = مرتين ونص عرض الشاشة (حركة أدق).
        _span = box.maxWidth * 2.5;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            _fling.stop();
            HapticFeedback.mediumImpact();
            widget.onChanged(widget.reset);
          },
          onHorizontalDragStart: (_) => _fling.stop(),
          onHorizontalDragUpdate: (d) =>
              _emit(widget.value + _dir * d.delta.dx / _span * _range),
          onHorizontalDragEnd: (d) {
            final v = _dir * d.velocity.pixelsPerSecond.dx / _span * _range;
            if (v.abs() < _range * 0.05) return;
            _fling.value = widget.value;
            _fling.animateWith(FrictionSimulation(0.02, widget.value, v));
          },
          child: RepaintBoundary(
            child: SizedBox(
              height: 58,
              child: Column(
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: (value - widget.reset).abs() > 0.004 ? 14 : 13,
                      color: (value - widget.reset).abs() > 0.004
                          ? b.primary
                          : b.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: Text(label),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _RulerPainter(
                        t: (value - widget.min) / _range,
                        zero: (widget.reset - widget.min) / _range,
                        span: _span,
                        tick: b.muted,
                        accent: b.primary,
                        rtl: Directionality.of(context) == TextDirection.rtl,
                      ),
                    ),
                  ),
                ],
              ),
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

/// معاينة صغيرة متحركة لنمط الفيديو (مربع رمادي = قبل، ملوّن = بعد).
class VideoStyleIcon extends StatefulWidget {
  final VideoStyle style;
  const VideoStyleIcon({super.key, required this.style});

  @override
  State<VideoStyleIcon> createState() => _VideoStyleIconState();
}

class _VideoStyleIconState extends State<VideoStyleIcon>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _StyleIconPainter(
          widget.style,
          Curves.easeInOut.transform(
            (_c.value < 0.5 ? _c.value * 2 : 2 - _c.value * 2).clamp(0, 1),
          ),
          b.muted,
          b.primary,
        ),
      ),
    );
  }
}

class _StyleIconPainter extends CustomPainter {
  final VideoStyle style;
  final double t;
  final Color before, after;
  _StyleIconPainter(this.style, this.t, this.before, this.after);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = before.withValues(alpha: 0.5),
    );
    final a = Paint()..color = after;
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    switch (style) {
      case VideoStyle.dissolve:
        canvas.drawRect(
          Offset.zero & size,
          a..color = after.withValues(alpha: t),
        );
      case VideoStyle.wipe:
      case VideoStyle.slider:
        final x = size.width * (style == VideoStyle.slider ? 0.2 + 0.6 * t : t);
        canvas.drawRect(Rect.fromLTWH(0, 0, x, size.height), a);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      case VideoStyle.rise:
        final y = size.height * (1 - t);
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, size.height - y), a);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      case VideoStyle.circle:
        final c = size.center(Offset.zero);
        canvas.drawCircle(c, size.longestSide * 0.75 * t, a);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StyleIconPainter o) => o.t != t || o.style != style;
}

/// دخول ناعم (يطلع من تحت ويوضح) بتأخير، حتى عناصر الشاشة تجي وحدة ورا وحدة.
class Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const Entrance({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 70).clamp(0, 600);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delay),
      curve: Interval(delay / (520 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 24),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// لمعة تمشي على الزر لما يكون جاهز (تجذب العين للخطوة الجاية).
class Shine extends StatefulWidget {
  final bool on;
  final BorderRadius radius;
  final Widget child;
  const Shine({
    super.key,
    required this.on,
    required this.radius,
    required this.child,
  });

  @override
  State<Shine> createState() => _ShineState();
}

class _ShineState extends State<Shine> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.on) _c.repeat();
  }

  @override
  void didUpdateWidget(Shine old) {
    super.didUpdateWidget(old);
    if (widget.on && !_c.isAnimating) _c.repeat();
    if (!widget.on) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.radius,
      child: Stack(
        children: [
          widget.child,
          if (widget.on)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final x = -1.6 + _c.value * 3.6;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(x - 0.5, -1),
                          end: Alignment(x + 0.5, 1),
                          colors: const [
                            Color(0x00FFFFFF),
                            Color(0x55FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// يضغط ويرجع بنعومة (إحساس زر حقيقي).
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const Pressable({super.key, required this.onTap, required this.child});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.onTap == null
        ? null
        : (_) => setState(() => _down = true),
    onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    onTap: widget.onTap == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}
