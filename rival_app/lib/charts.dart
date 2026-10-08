import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'brand.dart';

// ======================================================= خريطة الأسنان (FDI)

/// ترتيب العرض مثل ما يشوفه الطبيب مقابل المراجع:
/// يمين المراجع على يسار الشاشة. الفك العلوي ١٨←١١ | ٢١→٢٨، السفلي ٤٨←٤١ | ٣١→٣٨.
const permanentUpper = [
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
const permanentLower = [
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
const primaryUpper = [55, 54, 53, 52, 51, 61, 62, 63, 64, 65];
const primaryLower = [85, 84, 83, 82, 81, 71, 72, 73, 74, 75];

bool isPrimaryTooth(int fdi) => fdi ~/ 10 >= 5;

const _permanentNames = {
  1: 'قاطع مركزي',
  2: 'قاطع جانبي',
  3: 'ناب',
  4: 'ضاحك أول',
  5: 'ضاحك ثاني',
  6: 'رحى أولى',
  7: 'رحى ثانية',
  8: 'ضرس العقل',
};
const _primaryNames = {
  1: 'قاطع مركزي لبني',
  2: 'قاطع جانبي لبني',
  3: 'ناب لبني',
  4: 'رحى أولى لبنية',
  5: 'رحى ثانية لبنية',
};

/// الربع: ١ و٥ علوي يمين، ٢ و٦ علوي يسار، ٣ و٧ سفلي يسار، ٤ و٨ سفلي يمين (يمين المراجع).
bool isUpperTooth(int fdi) => const {1, 2, 5, 6}.contains(fdi ~/ 10);
bool isRightTooth(int fdi) => const {1, 4, 5, 8}.contains(fdi ~/ 10);

String toothName(int fdi) {
  final n = fdi % 10;
  final name =
      (isPrimaryTooth(fdi) ? _primaryNames : _permanentNames)[n] ?? 'سن';
  return '$name ${isUpperTooth(fdi) ? 'علوي' : 'سفلي'} ${isRightTooth(fdi) ? 'أيمن' : 'أيسر'}';
}

/// وصف مختصر للأسنان (للملخص الذكي بالتقرير).
String teethSummary(List<int> teeth) {
  if (teeth.isEmpty) return '';
  final groups = <String, int>{};
  for (final t in teeth) {
    final front = t % 10 <= 3;
    final key =
        '${front ? 'أمامية' : 'خلفية'} ${isUpperTooth(t) ? 'علوية' : 'سفلية'}';
    groups[key] = (groups[key] ?? 0) + 1;
  }
  return groups.entries.map((e) => '${ar(e.value)} ${e.key}').join('، ');
}

double _toothWidth(int fdi) {
  final n = fdi % 10;
  if (isPrimaryTooth(fdi)) {
    return const {1: 0.8, 2: 0.7, 3: 0.8, 4: 0.95, 5: 1.05}[n]!;
  }
  return const {
    1: 0.86,
    2: 0.74,
    3: 0.84,
    4: 0.8,
    5: 0.8,
    6: 1.12,
    7: 1.04,
    8: 0.96,
  }[n]!;
}

class ToothSpot {
  final int fdi;
  final Offset center;
  final double angle, width, height;
  const ToothSpot(this.fdi, this.center, this.angle, this.width, this.height);
}

/// أماكن الأسنان على قوسين (علوي وسفلي) بمقاس [size] (العرض : الارتفاع = ١ : ١).
List<ToothSpot> toothLayout(Size size, {required bool primary}) {
  final w = size.width;
  final spots = <ToothSpot>[];
  void arch(List<int> teeth, bool upper) {
    final cx = 0.5 * w;
    // القوسين متقابلين (العلوي ∩ والسفلي ∪) وبيناتهم مسافة حتى ما تتداخل الأضراس.
    final cy = (upper ? 0.42 : 0.58) * size.height;
    final rx = (primary ? 0.33 : 0.42) * w;
    final ry = (primary ? 0.27 : 0.35) * size.height;
    const a0 = math.pi, a1 = 0.0;
    final total = teeth.fold(0.0, (s, t) => s + _toothWidth(t));
    // طول القوس التقريبي حتى نحسب حجم السن.
    var arc = 0.0;
    var prev = Offset(cx + rx * math.cos(a0), cy);
    for (var k = 1; k <= 60; k++) {
      final a = a0 + (a1 - a0) * k / 60;
      final p = Offset(
        cx + rx * math.cos(a),
        cy + (upper ? -1 : 1) * ry * math.sin(a),
      );
      arc += (p - prev).distance;
      prev = p;
    }
    final unit = arc / total;
    var acc = 0.0;
    for (final t in teeth) {
      final mid = (acc + _toothWidth(t) / 2) / total;
      acc += _toothWidth(t);
      final a = a0 + (a1 - a0) * mid;
      final sign = upper ? -1.0 : 1.0;
      final c = Offset(cx + rx * math.cos(a), cy + sign * ry * math.sin(a));
      // اتجاه المماس حتى يدور السن ويه القوس.
      final tangent = Offset(-rx * math.sin(a), sign * ry * math.cos(a));
      spots.add(
        ToothSpot(
          t,
          c,
          math.atan2(tangent.dy, tangent.dx),
          unit * _toothWidth(t) * 0.86,
          unit *
              (t % 10 >= 6 || (isPrimaryTooth(t) && t % 10 >= 4) ? 1.0 : 1.15),
        ),
      );
    }
  }

  arch(primary ? primaryUpper : permanentUpper, true);
  arch(primary ? primaryLower : permanentLower, false);
  return spots;
}

int? toothAt(Size size, Offset p, {required bool primary}) {
  ToothSpot? best;
  var dist = double.infinity;
  for (final s in toothLayout(size, primary: primary)) {
    final d = (s.center - p).distance;
    if (d < dist) {
      dist = d;
      best = s;
    }
  }
  if (best == null || dist > math.max(best.width, best.height) * 0.75) {
    return null;
  }
  return best.fdi;
}

class ToothChartPainter extends CustomPainter {
  final Set<int> selected;
  final bool primary;
  final Brand brand;
  final double fontScale;
  ToothChartPainter({
    required this.selected,
    required this.primary,
    required this.brand,
    this.fontScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spots = toothLayout(size, primary: primary);
    final unit = size.width;
    _text(
      canvas,
      'الفك العلوي',
      Offset(size.width / 2, size.height * 0.3),
      unit * 0.032 * fontScale,
      brand.muted,
    );
    _text(
      canvas,
      'الفك السفلي',
      Offset(size.width / 2, size.height * 0.72),
      unit * 0.032 * fontScale,
      brand.muted,
    );
    _text(
      canvas,
      'يمين المراجع',
      Offset(size.width * 0.12, size.height * 0.94),
      unit * 0.03 * fontScale,
      brand.muted,
    );
    _text(
      canvas,
      'يسار المراجع',
      Offset(size.width * 0.88, size.height * 0.94),
      unit * 0.03 * fontScale,
      brand.muted,
    );
    // خط المنتصف.
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.06),
      Offset(size.width / 2, size.height * 0.98),
      Paint()
        ..color = brand.line
        ..strokeWidth = 1,
    );
    for (final s in spots) {
      final on = selected.contains(s.fdi);
      canvas.save();
      canvas.translate(s.center.dx, s.center.dy);
      canvas.rotate(s.angle);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s.width, height: s.height),
        Radius.circular(s.width * (s.fdi % 10 >= 4 ? 0.3 : 0.45)),
      );
      canvas.drawRRect(
        r,
        Paint()..color = on ? brand.primary : const Color(0xFFFFFFFF),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, unit * 0.003)
          ..color = on ? brand.primaryDeep : brand.line.withValues(alpha: 1),
      );
      canvas.restore();
      _text(
        canvas,
        '${s.fdi}',
        s.center,
        s.width * 0.36 * fontScale,
        on ? const Color(0xFFFFFFFF) : brand.muted,
        bold: true,
      );
    }
  }

  @override
  bool shouldRepaint(ToothChartPainter old) =>
      old.selected != selected || old.primary != primary || old.brand != brand;
}

// ======================================================= خريطة الوجه

class FaceArea {
  final String id, label;
  final Offset center; // نسبة من العرض (x) ومن العرض أيضاً (y)
  final double rx, ry;
  const FaceArea(this.id, this.label, this.center, this.rx, this.ry);

  Rect rect(Size s) => Rect.fromCenter(
    center: Offset(center.dx * s.width, center.dy * s.width),
    width: rx * 2 * s.width,
    height: ry * 2 * s.width,
  );
}

/// مناطق الوجه. يمين المراجعة على يسار الشاشة.
const faceAreas = [
  FaceArea('forehead', 'الجبهة', Offset(0.5, 0.25), 0.2, 0.07),
  FaceArea('glabella', 'بين الحاجبين', Offset(0.5, 0.375), 0.045, 0.035),
  FaceArea('temple_r', 'الصدغ الأيمن', Offset(0.215, 0.36), 0.042, 0.065),
  FaceArea('temple_l', 'الصدغ الأيسر', Offset(0.785, 0.36), 0.042, 0.065),
  FaceArea('crow_r', 'جانب العين الأيمن', Offset(0.265, 0.475), 0.028, 0.04),
  FaceArea('crow_l', 'جانب العين الأيسر', Offset(0.735, 0.475), 0.028, 0.04),
  FaceArea('undereye_r', 'تحت العين اليمنى', Offset(0.36, 0.53), 0.075, 0.027),
  FaceArea('undereye_l', 'تحت العين اليسرى', Offset(0.64, 0.53), 0.075, 0.027),
  FaceArea('nose', 'الأنف', Offset(0.5, 0.57), 0.042, 0.085),
  FaceArea('cheek_r', 'الخد الأيمن', Offset(0.29, 0.62), 0.075, 0.065),
  FaceArea('cheek_l', 'الخد الأيسر', Offset(0.71, 0.62), 0.075, 0.065),
  FaceArea(
    'nasolabial_r',
    'الخط الأنفي الأيمن',
    Offset(0.405, 0.675),
    0.025,
    0.05,
  ),
  FaceArea(
    'nasolabial_l',
    'الخط الأنفي الأيسر',
    Offset(0.595, 0.675),
    0.025,
    0.05,
  ),
  FaceArea('lips', 'الشفايف', Offset(0.5, 0.74), 0.085, 0.036),
  FaceArea(
    'marionette_r',
    'خط الماريونيت الأيمن',
    Offset(0.405, 0.815),
    0.025,
    0.04,
  ),
  FaceArea(
    'marionette_l',
    'خط الماريونيت الأيسر',
    Offset(0.595, 0.815),
    0.025,
    0.04,
  ),
  FaceArea('chin', 'الذقن', Offset(0.5, 0.9), 0.07, 0.04),
  FaceArea('jaw_r', 'خط الفك الأيمن', Offset(0.25, 0.8), 0.045, 0.08),
  FaceArea('jaw_l', 'خط الفك الأيسر', Offset(0.75, 0.8), 0.045, 0.08),
  FaceArea('neck', 'الرقبة', Offset(0.5, 1.13), 0.12, 0.075),
];

/// الوجه أطول من عرضه: الارتفاع = ١.٢٥ × العرض.
const faceAspect = 1.25;

/// أسماء النسخة الأولى (نصوص حرة) تتحول لمناطق الخريطة.
const legacyAreaIds = {
  'الشفايف': 'lips',
  'الجبهة': 'forehead',
  'الذقن': 'chin',
  'الأنف': 'nose',
  'الرقبة': 'neck',
};

String areaLabel(String id) {
  for (final a in faceAreas) {
    if (a.id == id) return a.label;
  }
  return id;
}

String? faceAreaAt(Size size, Offset p) {
  FaceArea? best;
  var bestArea = double.infinity;
  for (final a in faceAreas) {
    final r = a.rect(size);
    final d = Offset(
      (p.dx - r.center.dx) / (r.width / 2),
      (p.dy - r.center.dy) / (r.height / 2),
    );
    // داخل البيضة (مع هامش بسيط حتى اللمس يكون سهل).
    if (d.distanceSquared <= 1.35) {
      final area = r.width * r.height;
      if (area < bestArea) {
        bestArea = area;
        best = a;
      }
    }
  }
  return best?.id;
}

class FaceMapPainter extends CustomPainter {
  final Set<String> selected;
  final Map<String, String> doses;
  final Brand brand;
  final bool showDoses;
  FaceMapPainter({
    required this.selected,
    required this.brand,
    this.doses = const {},
    this.showDoses = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    Offset p(double x, double y) => Offset(x * w, y * w);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.005)
      ..strokeCap = StrokeCap.round
      ..color = brand.accent;
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.0035)
      ..strokeCap = StrokeCap.round
      ..color = brand.accent.withValues(alpha: 0.75);

    // الرقبة والكتفين.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.38, 0.95).dx, p(0.38, 0.95).dy)
        ..quadraticBezierTo(
          p(0.37, 1.08).dx,
          p(0.36, 1.13).dy,
          p(0.2, 1.2).dx,
          p(0.2, 1.2).dy,
        )
        ..moveTo(p(0.62, 0.95).dx, p(0.62, 0.95).dy)
        ..quadraticBezierTo(
          p(0.63, 1.08).dx,
          p(0.64, 1.13).dy,
          p(0.8, 1.2).dx,
          p(0.8, 1.2).dy,
        ),
      line,
    );
    // الوجه: جبهة عريضة وذقن ناعم.
    final face = Path()
      ..moveTo(p(0.5, 0.1).dx, p(0.5, 0.1).dy)
      ..cubicTo(
        p(0.73, 0.1).dx,
        p(0.73, 0.1).dy,
        p(0.84, 0.25).dx,
        p(0.84, 0.25).dy,
        p(0.83, 0.47).dx,
        p(0.83, 0.47).dy,
      )
      ..cubicTo(
        p(0.83, 0.68).dx,
        p(0.83, 0.68).dy,
        p(0.74, 0.86).dx,
        p(0.74, 0.86).dy,
        p(0.62, 0.93).dx,
        p(0.62, 0.93).dy,
      )
      ..quadraticBezierTo(
        p(0.5, 0.99).dx,
        p(0.5, 0.99).dy,
        p(0.38, 0.93).dx,
        p(0.38, 0.93).dy,
      )
      ..cubicTo(
        p(0.26, 0.86).dx,
        p(0.26, 0.86).dy,
        p(0.17, 0.68).dx,
        p(0.17, 0.68).dy,
        p(0.17, 0.47).dx,
        p(0.17, 0.47).dy,
      )
      ..cubicTo(
        p(0.16, 0.25).dx,
        p(0.16, 0.25).dy,
        p(0.27, 0.1).dx,
        p(0.27, 0.1).dy,
        p(0.5, 0.1).dx,
        p(0.5, 0.1).dy,
      )
      ..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawPath(face, line);
    // الأذنين.
    for (final s in [-1.0, 1.0]) {
      final x = 0.5 + s * 0.335;
      canvas.drawArc(
        Rect.fromCenter(center: p(x, 0.52), width: w * 0.07, height: w * 0.16),
        s < 0 ? math.pi * 0.5 : -math.pi * 0.5,
        math.pi,
        false,
        soft,
      );
    }
    // الحواجب والعيون.
    for (final s in [-1.0, 1.0]) {
      final cx = 0.5 + s * 0.14;
      canvas.drawPath(
        Path()
          ..moveTo(p(cx - s * 0.08, 0.425).dx, p(cx, 0.425).dy)
          ..quadraticBezierTo(
            p(cx, 0.385).dx,
            p(cx, 0.385).dy,
            p(cx + s * 0.08, 0.42).dx,
            p(cx, 0.42).dy,
          ),
        line,
      );
      final eye = Path()
        ..moveTo(p(cx - 0.065, 0.48).dx, p(cx, 0.48).dy)
        ..quadraticBezierTo(
          p(cx, 0.445).dx,
          p(cx, 0.445).dy,
          p(cx + 0.065, 0.48).dx,
          p(cx, 0.48).dy,
        )
        ..quadraticBezierTo(
          p(cx, 0.505).dx,
          p(cx, 0.505).dy,
          p(cx - 0.065, 0.48).dx,
          p(cx, 0.48).dy,
        );
      canvas.drawPath(eye, soft);
      canvas.drawCircle(p(cx, 0.477), w * 0.012, Paint()..color = brand.accent);
    }
    // الأنف.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.485, 0.47).dx, p(0.485, 0.47).dy)
        ..quadraticBezierTo(
          p(0.47, 0.58).dx,
          p(0.47, 0.58).dy,
          p(0.455, 0.615).dx,
          p(0.455, 0.615).dy,
        )
        ..quadraticBezierTo(
          p(0.5, 0.64).dx,
          p(0.5, 0.64).dy,
          p(0.545, 0.615).dx,
          p(0.545, 0.615).dy,
        ),
      soft,
    );
    // الشفايف.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.42, 0.74).dx, p(0.42, 0.74).dy)
        ..quadraticBezierTo(
          p(0.46, 0.715).dx,
          p(0.46, 0.715).dy,
          p(0.5, 0.728).dx,
          p(0.5, 0.728).dy,
        )
        ..quadraticBezierTo(
          p(0.54, 0.715).dx,
          p(0.54, 0.715).dy,
          p(0.58, 0.74).dx,
          p(0.58, 0.74).dy,
        )
        ..quadraticBezierTo(
          p(0.5, 0.775).dx,
          p(0.5, 0.775).dy,
          p(0.42, 0.74).dx,
          p(0.42, 0.74).dy,
        ),
      soft,
    );

    for (final a in faceAreas) {
      final r = a.rect(size);
      final on = selected.contains(a.id);
      canvas.drawOval(
        r,
        Paint()
          ..color = on
              ? brand.primary.withValues(alpha: 0.42)
              : brand.highlight.withValues(alpha: 0.07),
      );
      canvas.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, w * (on ? 0.005 : 0.0025))
          ..color = on
              ? brand.primary
              : brand.highlight.withValues(alpha: 0.35),
      );
      if (on && showDoses && (doses[a.id] ?? '').isNotEmpty) {
        _pill(canvas, doses[a.id]!, r.center, w * 0.026, brand);
      }
    }
  }

  @override
  bool shouldRepaint(FaceMapPainter old) => true;
}

// ======================================================= مشترك

void _text(
  Canvas canvas,
  String text,
  Offset center,
  double size,
  Color color, {
  bool bold = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: kFontUi,
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

void _pill(Canvas canvas, String text, Offset center, double size, Brand b) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: kFontUi,
        fontSize: size,
        color: const Color(0xFFFFFFFF),
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final r = Rect.fromCenter(
    center: center,
    width: tp.width + size,
    height: tp.height + size * 0.4,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)),
    Paint()..color = b.primary,
  );
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

/// يرسم الرسمة لصورة PNG (للتقرير).
Future<Uint8List> paintToPng(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  final img = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}
