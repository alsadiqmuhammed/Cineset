import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'brand.dart';

/// خطوط العيادة اللي تنكتب بيها النصوص على التصميم.
const designFonts = [
  (kFontUi, 'المرعي'),
  (kFontReport, 'تجوال'),
  (kFontAccent, 'رقعة'),
];

enum ElementRole {
  doctor('اسم الطبيب'),
  text('نص'),
  signature('توقيع'),
  image('صورة');

  final String label;
  const ElementRole(this.label);
}

/// عنصر يتحرك فوق التصميم: نص (بخط العيادة) أو صورة PNG (توقيع، ختم...).
/// المكان نسبة من عرض وارتفاع التصميم، فيبقى بمكانه لو تغيّر المقاس.
class DesignElement {
  final ElementRole role;
  String text;
  String font;
  Color color;

  /// شريط خلفية ورا النص.
  bool pill;
  Color pillColor;
  ui.Image? image;

  /// مركز العنصر (٠-١ من العرض والارتفاع).
  Offset center;

  /// النص: حجم الخط نسبة من العرض. الصورة: عرضها نسبة من عرض التصميم.
  double size;
  double rotation;

  DesignElement.text(
    this.text, {
    this.role = ElementRole.text,
    this.font = kFontUi,
    this.color = const Color(0xFFFFFFFF),
    this.pill = false,
    this.pillColor = const Color(0xFF231F20),
    this.center = const Offset(0.5, 0.5),
    this.size = 0.045,
    this.rotation = 0,
  }) : image = null;

  DesignElement.image(
    ui.Image this.image, {
    this.role = ElementRole.image,
    this.center = const Offset(0.5, 0.5),
    this.size = 0.3,
    this.rotation = 0,
  }) : text = '',
       font = kFontUi,
       color = const Color(0xFFFFFFFF),
       pill = false,
       pillColor = const Color(0x00000000);

  bool get isText => image == null;

  Offset centerIn(Size s) => Offset(center.dx * s.width, center.dy * s.height);

  TextPainter _painter(Size s) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: font,
        fontSize: size * s.width,
        fontWeight: font == kFontAccent ? FontWeight.w700 : FontWeight.w800,
        color: color,
        height: 1.35,
        shadows: pill
            ? null
            : [
                Shadow(
                  color: const Color(0x73000000),
                  blurRadius: size * s.width * 0.18,
                  offset: Offset(0, size * s.width * 0.04),
                ),
              ],
      ),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  )..layout(maxWidth: s.width * 0.95);

  /// مقاس العنصر (قبل التدوير) بالبكسل.
  Size boxIn(Size s) {
    if (!isText) {
      final w = size * s.width;
      return Size(w, w * image!.height / image!.width);
    }
    final tp = _painter(s);
    final pad = pill ? size * s.width * 0.6 : size * s.width * 0.15;
    final out = Size(tp.width + pad * 2, tp.height + pad * 0.5);
    tp.dispose();
    return out;
  }

  /// هل النقطة [p] (بكسلات التصميم) على العنصر؟
  bool hit(Size s, Offset p, {double slop = 0}) {
    final local = _rot(p, centerIn(s));
    final box = boxIn(s);
    return Rect.fromCenter(
      center: Offset.zero,
      width: box.width + slop * 2,
      height: box.height + slop * 2,
    ).contains(local);
  }

  Offset _rot(Offset p, Offset c) {
    final d = p - c;
    final cs = math.cos(-rotation), sn = math.sin(-rotation);
    return Offset(d.dx * cs - d.dy * sn, d.dx * sn + d.dy * cs);
  }

  /// الحدود (بدون تدوير) حول المركز.
  Rect rectIn(Size s) {
    final box = boxIn(s);
    return Rect.fromCenter(
      center: centerIn(s),
      width: box.width,
      height: box.height,
    );
  }

  void paint(Canvas canvas, Size s) {
    final c = centerIn(s);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    if (!isText) {
      final box = boxIn(s);
      canvas.drawImageRect(
        image!,
        Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
        Rect.fromCenter(
          center: Offset.zero,
          width: box.width,
          height: box.height,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      final tp = _painter(s);
      if (pill) {
        final box = boxIn(s);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: box.width,
              height: box.height,
            ),
            Radius.circular(box.height / 2),
          ),
          Paint()..color = pillColor,
        );
      }
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      tp.dispose();
    }
    canvas.restore();
  }

  /// إطار التحديد بالمعاينة (ما ينطبع بالتصدير).
  void paintSelection(Canvas canvas, Size s, Color color) {
    final c = centerIn(s);
    final box = boxIn(s);
    final pad = s.width * 0.012;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: box.width + pad * 2,
      height: box.height + pad * 2,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.004
      ..color = color;
    // خط متقطع.
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(pad)));
    for (final m in path.computeMetrics()) {
      final dash = s.width * 0.018;
      for (var d = 0.0; d < m.length; d += dash * 1.8) {
        canvas.drawPath(m.extractPath(d, d + dash), stroke);
      }
    }
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawCircle(corner, s.width * 0.009, Paint()..color = color);
    }
    canvas.restore();
  }
}

void paintElements(Canvas canvas, Size size, List<DesignElement> elements) {
  for (final e in elements) {
    e.paint(canvas, size);
  }
}

/// آخر عنصر (الأعلى) تحت النقطة.
DesignElement? elementAt(List<DesignElement> elements, Size s, Offset p) {
  for (final e in elements.reversed) {
    if (e.hit(s, p, slop: s.width * 0.02)) return e;
  }
  return null;
}

/// أحسن مكان لاسم الطبيب: أول مكان من [candidates] ما يتداخل وية شارات
/// قبل/بعد ولا يطلع برا التصميم.
Offset placeAvoiding(
  DesignElement e,
  Size s,
  List<Offset> candidates,
  List<Rect> avoid,
) {
  for (final c in candidates) {
    e.center = c;
    final r = e.rectIn(s).inflate(s.width * 0.01);
    final inside =
        (Offset.zero & s).contains(r.topLeft) &&
        (Offset.zero & s).contains(r.bottomRight);
    if (inside && !avoid.any(r.overlaps)) return c;
  }
  return e.center = candidates.first;
}
