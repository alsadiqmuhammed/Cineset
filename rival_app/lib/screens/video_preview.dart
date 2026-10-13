import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../video.dart';

/// توقيت الفيديو (نفس اللي ينبعث لكود التلفون).
class VideoTiming {
  final double holdBefore, morph, holdAfter;
  const VideoTiming(this.holdBefore, this.morph, this.holdAfter);

  factory VideoTiming.of(VideoStyle style, int speed) {
    final (hold, morph) = switch (speed) {
      0 => (0.6, 1.4),
      2 => (1.4, 3.6),
      _ => (1.0, 2.4),
    };
    return VideoTiming(
      hold,
      style == VideoStyle.slider ? morph * 1.4 : morph,
      hold * 1.6,
    );
  }

  double get total => holdBefore + morph + holdAfter;
}

double _ease(double x) => x * x * (3 - 2 * x);

/// معاينة حيّة للفيديو داخل التطبيق: نفس الانتقال والتقريب والخط اللي
/// يطلع بالملف، وتعيد نفسها.
class VideoPreview extends StatefulWidget {
  final ui.Image before, after, overlay;
  final VideoStyle style;
  final VideoTiming timing;
  final Color line;
  const VideoPreview({
    super.key,
    required this.before,
    required this.after,
    required this.overlay,
    required this.style,
    required this.timing,
    required this.line,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.timing.total * 1000).round()),
  )..repeat();

  @override
  void didUpdateWidget(VideoPreview old) {
    super.didUpdateWidget(old);
    final d = Duration(milliseconds: (widget.timing.total * 1000).round());
    if (_c.duration != d || old.style != widget.style) {
      _c.duration = d;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      size: Size.infinite,
      painter: _PreviewPainter(widget, _c.value * widget.timing.total),
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  final VideoPreview w;
  final double t;
  _PreviewPainter(this.w, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final tm = w.timing;
    final p = ((t - tm.holdBefore) / tm.morph).clamp(0.0, 1.0);
    final mix = _ease(p);
    final edge = switch (w.style) {
      VideoStyle.slider =>
        p < 0.4
            ? 0.8 * _ease(p / 0.4)
            : p < 0.75
            ? 0.8 - 0.55 * _ease((p - 0.4) / 0.35)
            : 0.25 + 0.25 * _ease((p - 0.75) / 0.25),
      VideoStyle.rise => 1 - mix,
      _ => mix,
    };
    final zoom = 1 + 0.06 * (t / tm.total);
    final full = Offset.zero & size;
    void img(ui.Image i, [Paint? paint]) => canvas.drawImageRect(
      i,
      Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble()),
      full,
      paint ?? (Paint()..filterQuality = FilterQuality.medium),
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-size.width / 2, -size.height / 2);
    img(w.before);
    switch (w.style) {
      case VideoStyle.dissolve:
        img(
          w.after,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(0, 0, 0, mix),
        );
      case VideoStyle.wipe:
      case VideoStyle.slider:
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, size.width * edge, size.height));
        img(w.after);
        canvas.restore();
      case VideoStyle.rise:
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(0, size.height * edge, size.width, size.height),
        );
        img(w.after);
        canvas.restore();
      case VideoStyle.circle:
        if (mix > 0) {
          canvas.save();
          canvas.clipPath(
            Path()..addOval(
              Rect.fromCircle(
                center: size.center(Offset.zero),
                radius: mix * 0.75 * size.width,
              ),
            ),
          );
          img(w.after);
          canvas.restore();
        }
    }
    canvas.restore();
    final line = Paint()
      ..color = w.line
      ..strokeWidth = math.max(1.5, size.width * 0.006);
    if (edge > 0.001 && edge < 0.999) {
      if (w.style == VideoStyle.wipe || w.style == VideoStyle.slider) {
        canvas.drawLine(
          Offset(size.width * edge, 0),
          Offset(size.width * edge, size.height),
          line,
        );
      } else if (w.style == VideoStyle.rise) {
        canvas.drawLine(
          Offset(0, size.height * edge),
          Offset(size.width, size.height * edge),
          line,
        );
      }
    }
    if (w.style == VideoStyle.circle && mix > 0.001 && mix < 0.999) {
      canvas.drawCircle(
        size.center(Offset.zero),
        mix * 0.75 * size.width,
        line..style = PaintingStyle.stroke,
      );
    }
    img(w.overlay);
  }

  @override
  bool shouldRepaint(_PreviewPainter o) => o.t != t || o.w != w;
}
