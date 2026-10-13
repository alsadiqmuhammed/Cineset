import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
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

/// السن اللبني اللي ينبت بمكان السن الدائمي (القواطع والناب والضواحك فقط).
int? deciduousOf(int fdi) {
  if (isPrimaryTooth(fdi)) return fdi;
  final n = fdi % 10;
  return n <= 5 ? (fdi ~/ 10 + 4) * 10 + n : null;
}

/// مكان السن (الرقم الدائمي) لأي سن لبني أو دائمي.
int positionOf(int fdi) =>
    isPrimaryTooth(fdi) ? (fdi ~/ 10 - 4) * 10 + fdi % 10 : fdi;

/// عمر بزوغ السن الدائمي تقريباً (بالسنين).
int eruptionAge(int position) {
  final n = position % 10;
  return isUpperTooth(position)
      ? const {1: 7, 2: 8, 3: 11, 4: 10, 5: 10, 6: 6, 7: 12, 8: 18}[n]!
      : const {1: 6, 2: 7, 3: 9, 4: 10, 5: 11, 6: 6, 7: 11, 8: 18}[n]!;
}

const allPositions = [...permanentUpper, ...permanentLower];

/// الأماكن اللي بيها سن لبني حسب العمر (دائمي ما طلع بعد).
Set<int> deciduousByAge(int? age) => age == null
    ? {}
    : {
        for (final t in allPositions)
          if (deciduousOf(t) != null && age < eruptionAge(t)) t,
      };

/// الأضراس الدائمية اللي ما طالعة بعد حسب العمر (تنرسم باهتة).
Set<int> uneruptedByAge(int? age) => age == null
    ? {}
    : {
        for (final t in allPositions)
          if (deciduousOf(t) == null && age < eruptionAge(t)) t,
      };

/// الأماكن اللبنية الفعلية: اختيار الطبيب (أو العمر)، وأي سن لبني مؤشر.
Set<int> effectiveDeciduous(
  Set<int>? manual,
  int? age,
  Iterable<int> selected,
) => {
  ...(manual ?? deciduousByAge(age)),
  for (final t in selected)
    if (isPrimaryTooth(t)) positionOf(t),
};

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

  /// اتجاه القوس عند السن (بالراديان).
  final double angle;

  /// العرض على طول القوس، والعمق باتجاه الحنك.
  final double width, height;
  const ToothSpot(this.fdi, this.center, this.angle, this.width, this.height);
}

/// الخريطة أطول من عرضها: الفك العلوي فوق والسفلي جوّه، كل واحد بمكانه.
const teethAspect = 1.25;

/// منحنى القوس (بيزيه) بإحداثيات نسبة من العرض. العلوي ∩ (القواطع فوق)،
/// والسفلي ∪ (القواطع جوّه).
List<Offset> _archControl({required bool upper}) {
  const pts = [
    Offset(0.18, 0.55),
    Offset(0.12, 0.02),
    Offset(0.88, 0.02),
    Offset(0.82, 0.55),
  ];
  if (upper) return pts;
  return [for (final p in pts) Offset(p.dx, teethAspect - p.dy)];
}

Offset _bezier(List<Offset> c, double t) {
  final u = 1 - t;
  return c[0] * (u * u * u) +
      c[1] * (3 * u * u * t) +
      c[2] * (3 * u * t * t) +
      c[3] * (t * t * t);
}

/// نقاط القوس متساوية المسافة تقريباً: (النقطة، الاتجاه) لكل جزء من الطول.
class _Arch {
  final List<Offset> pts = [];
  final List<double> len = [0];
  _Arch(List<Offset> control, double w) {
    for (var i = 0; i <= 240; i++) {
      pts.add(_bezier(control, i / 240) * w);
      if (i > 0) len.add(len.last + (pts[i] - pts[i - 1]).distance);
    }
  }
  double get total => len.last;

  (Offset, double) at(double s) {
    var i = 1;
    while (i < len.length - 1 && len[i] < s) {
      i++;
    }
    final a = pts[i - 1], b = pts[i];
    final f = ((s - len[i - 1]) / (len[i] - len[i - 1])).clamp(0.0, 1.0);
    final d = b - a;
    return (Offset.lerp(a, b, f)!, math.atan2(d.dy, d.dx));
  }

  Path path() {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p;
  }
}

/// العمق (باتجاه الحنك) نسبة من وحدة القوس، حسب نوع السن.
double _toothDepth(int fdi) {
  final n = fdi % 10;
  if (isPrimaryTooth(fdi)) return n <= 2 ? 0.62 : (n == 3 ? 0.78 : 0.95);
  return const {
    1: 0.62,
    2: 0.6,
    3: 0.8,
    4: 0.92,
    5: 0.92,
    6: 1.08,
    7: 1.02,
    8: 0.95,
  }[n]!;
}

/// أماكن الأسنان الـ٣٢ بمقاس [size] (العرض : الارتفاع = ١ : ١.٢٥).
/// السن اللبني ينرسم بنفس مكان الدائمي اللي يطلع بداله.
List<ToothSpot> toothLayout(Size size) {
  final w = size.width;
  final spots = <ToothSpot>[];
  void arch(List<int> teeth, bool upper) {
    final a = _Arch(_archControl(upper: upper), w);
    final total = teeth.fold(0.0, (s, t) => s + _toothWidth(t));
    final unit = a.total / total;
    var acc = 0.0;
    for (final t in teeth) {
      final (c, angle) = a.at((acc + _toothWidth(t) / 2) * unit);
      acc += _toothWidth(t);
      spots.add(
        ToothSpot(
          t,
          c,
          angle,
          unit * _toothWidth(t) * 0.97,
          unit * _toothDepth(t) * 1.18,
        ),
      );
    }
  }

  arch(permanentUpper, true);
  arch(permanentLower, false);
  return spots;
}

/// مكان السن (الرقم الدائمي) تحت النقطة [p].
int? toothAt(Size size, Offset p) {
  ToothSpot? best;
  var dist = double.infinity;
  for (final s in toothLayout(size)) {
    final d = (s.center - p).distance;
    if (d < dist) {
      dist = d;
      best = s;
    }
  }
  if (best == null || dist > math.max(best.width, best.height) * 0.8) {
    return null;
  }
  return best.fdi;
}

const _gum = Color(0xFFE59AA2);
const _gumEdge = Color(0xFFC9727D);
const _palate = Color(0xFFF2B9BE);
const _enamel = Color(0xFFFFFDF8);
const _enamelShade = Color(0xFFE9E1D3);
const _enamelLine = Color(0xFFC9BDAA);
const _babyEnamel = Color(0xFFFFF4DC);
const _babyEnamelShade = Color(0xFFF1DDB4);

/// خريطة الأسنان مرسومة مثل الرسوم الطبية: لثة وحنك، وأسنان من فوق
/// (القواطع رفيعة، والأضراس بخطوط تيجانها). بدون أرقام.
class ToothChartPainter extends CustomPainter {
  /// الأسنان المؤشرة (أرقام FDI دائمية أو لبنية).
  final Set<int> selected;

  /// الأماكن اللي بيها سن لبني (بالرقم الدائمي للمكان).
  final Set<int> deciduous;

  /// الأضراس الدائمية اللي ما طالعة بعد (تنرسم باهتة).
  final Set<int> unerupted;
  final Brand brand;
  final double fontScale;
  final bool labels;
  ToothChartPainter({
    required this.selected,
    required this.brand,
    this.deciduous = const {},
    this.unerupted = const {},
    this.fontScale = 1,
    this.labels = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final spots = toothLayout(size);
    final unit = spots.first.width / _toothWidth(spots.first.fdi) / 0.97;
    for (final upper in [true, false]) {
      final a = _Arch(_archControl(upper: upper), w);
      final path = a.path();
      // الحنك (أو مكان اللسان) داخل القوس.
      final inner = Path.from(path)..close();
      canvas.drawPath(
        inner,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(w / 2, (upper ? 0.32 : teethAspect - 0.32) * w),
            w * 0.4,
            [_palate.withValues(alpha: 0.95), _gum.withValues(alpha: 0.9)],
          ),
      );
      // اللثة: شريط عريض على طول القوس.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 1.62
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _gumEdge,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 1.48
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _gum,
      );
    }
    for (final s in spots) {
      final baby = deciduous.contains(s.fdi) && deciduousOf(s.fdi) != null;
      final code = baby ? deciduousOf(s.fdi)! : s.fdi;
      final spot = baby
          ? ToothSpot(code, s.center, s.angle, s.width * 0.8, s.height * 0.8)
          : s;
      final faded = !baby && unerupted.contains(s.fdi);
      if (faded) {
        canvas.saveLayer(null, Paint()..color = const Color(0x59000000));
      }
      _tooth(canvas, spot, selected.contains(code), w, baby: baby);
      if (faded) canvas.restore();
    }
    if (!labels) return;
    final f = w * 0.034 * fontScale;
    _text(canvas, 'الفك العلوي', Offset(w / 2, w * 0.33), f, brand.muted);
    _text(
      canvas,
      'الفك السفلي',
      Offset(w / 2, w * (teethAspect - 0.33)),
      f,
      brand.muted,
    );
    _text(
      canvas,
      'يمين المراجع',
      Offset(w * 0.37, w * teethAspect / 2),
      f * 0.85,
      brand.muted,
    );
    _text(
      canvas,
      'يسار المراجع',
      Offset(w * 0.63, w * teethAspect / 2),
      f * 0.85,
      brand.muted,
    );
  }

  void _tooth(
    Canvas canvas,
    ToothSpot s,
    bool on,
    double w, {
    bool baby = false,
  }) {
    final n = s.fdi % 10;
    final molar = isPrimaryTooth(s.fdi) ? n >= 4 : n >= 6;
    final premolar = !isPrimaryTooth(s.fdi) && (n == 4 || n == 5);
    final canine = n == 3;
    canvas.save();
    canvas.translate(s.center.dx, s.center.dy);
    canvas.rotate(s.angle);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: s.width,
      height: s.height,
    );
    final shape = molar
        ? RRect.fromRectAndRadius(rect, Radius.circular(s.width * 0.34))
        : premolar
        ? RRect.fromRectAndRadius(rect, Radius.circular(s.width * 0.45))
        : RRect.fromRectAndRadius(
            rect,
            Radius.elliptical(s.width * 0.5, s.height * 0.5),
          );
    // ظل خفيف تحت السن.
    canvas.drawRRect(
      shape.shift(Offset(0, s.height * 0.06)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.06),
    );
    final top = on
        ? Color.lerp(brand.primary, Colors.white, 0.25)!
        : (baby ? _babyEnamel : _enamel);
    final bottom = on
        ? brand.primaryDeep
        : (baby ? _babyEnamelShade : _enamelShade);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-s.width * 0.15, -s.height * 0.2),
          s.width * 0.75,
          [top, bottom],
        ),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.0025)
        ..color = on ? brand.primaryDeep : _enamelLine,
    );
    // خطوط التاج: صليب للأضراس، خط للضواحك، نقطة للناب.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.7, w * 0.0022)
      ..color = on ? Colors.white.withValues(alpha: 0.7) : _enamelLine;
    if (molar) {
      final gx = s.width * 0.22, gy = s.height * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(-gx, -gy * 0.3)
          ..quadraticBezierTo(0, gy * 0.3, gx, -gy * 0.3)
          ..moveTo(-gx * 0.2, -gy)
          ..quadraticBezierTo(gx * 0.25, 0, -gx * 0.1, gy),
        groove,
      );
    } else if (premolar) {
      canvas.drawLine(
        Offset(-s.width * 0.22, 0),
        Offset(s.width * 0.22, 0),
        groove,
      );
    } else if (canine) {
      canvas.drawCircle(Offset.zero, s.width * 0.06, groove);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ToothChartPainter old) =>
      old.selected != selected ||
      old.deciduous != deciduous ||
      old.unerupted != unerupted ||
      old.brand != brand;
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
  FaceArea('forehead', 'الجبهة', Offset(0.5, 0.28), 0.17, 0.06),
  FaceArea('glabella', 'بين الحاجبين', Offset(0.5, 0.405), 0.035, 0.03),
  FaceArea('temple_r', 'الصدغ الأيمن', Offset(0.24, 0.38), 0.035, 0.055),
  FaceArea('temple_l', 'الصدغ الأيسر', Offset(0.76, 0.38), 0.035, 0.055),
  FaceArea('crow_r', 'جانب العين الأيمن', Offset(0.27, 0.46), 0.026, 0.035),
  FaceArea('crow_l', 'جانب العين الأيسر', Offset(0.73, 0.46), 0.026, 0.035),
  FaceArea('undereye_r', 'تحت العين اليمنى', Offset(0.37, 0.52), 0.055, 0.022),
  FaceArea('undereye_l', 'تحت العين اليسرى', Offset(0.63, 0.52), 0.055, 0.022),
  FaceArea('nose', 'الأنف', Offset(0.5, 0.56), 0.035, 0.065),
  FaceArea('cheek_r', 'الخد الأيمن', Offset(0.315, 0.605), 0.06, 0.055),
  FaceArea('cheek_l', 'الخد الأيسر', Offset(0.685, 0.605), 0.06, 0.055),
  FaceArea(
    'nasolabial_r',
    'الخط الأنفي الأيمن',
    Offset(0.415, 0.655),
    0.02,
    0.042,
  ),
  FaceArea(
    'nasolabial_l',
    'الخط الأنفي الأيسر',
    Offset(0.585, 0.655),
    0.02,
    0.042,
  ),
  FaceArea('lip_upper', 'الشفة العليا', Offset(0.5, 0.706), 0.065, 0.016),
  FaceArea('lip_lower', 'الشفة السفلى', Offset(0.5, 0.742), 0.065, 0.018),
  FaceArea(
    'marionette_r',
    'خط الماريونيت الأيمن',
    Offset(0.42, 0.795),
    0.02,
    0.035,
  ),
  FaceArea(
    'marionette_l',
    'خط الماريونيت الأيسر',
    Offset(0.58, 0.795),
    0.02,
    0.035,
  ),
  FaceArea('chin', 'الذقن', Offset(0.5, 0.885), 0.055, 0.035),
  FaceArea('jaw_r', 'خط الفك الأيمن', Offset(0.275, 0.765), 0.035, 0.065),
  FaceArea('jaw_l', 'خط الفك الأيسر', Offset(0.725, 0.765), 0.035, 0.065),
  FaceArea('neck', 'الرقبة', Offset(0.5, 1.04), 0.07, 0.045),
];

/// الوجه أطول من عرضه: الارتفاع = ١.٢٥ × العرض.
const faceAspect = 1.25;

/// أسماء النسخ القديمة تتحول لمناطق الخريطة (الشفايف صارت شفتين).
const legacyAreaIds = {
  'الشفايف': ['lip_upper', 'lip_lower'],
  'lips': ['lip_upper', 'lip_lower'],
  'الجبهة': ['forehead'],
  'الذقن': ['chin'],
  'الأنف': ['nose'],
  'الرقبة': ['neck'],
};

String areaLabel(String id) {
  for (final a in faceAreas) {
    if (a.id == id) return a.label;
  }
  return id;
}

String? faceAreaAt(Size size, Offset p) {
  FaceArea? best;
  var bestScore = double.infinity;
  for (final a in faceAreas) {
    final r = a.rect(size);
    // المناطق الصغيرة إلها مساحة لمس أكبر من رسمتها حتى يسهل اختيارها.
    final hx = math.max(r.width / 2, size.width * 0.04);
    final hy = math.max(r.height / 2, size.width * 0.04);
    final d = Offset((p.dx - r.center.dx) / hx, (p.dy - r.center.dy) / hy);
    final score = d.distanceSquared;
    if (score <= 1.2 && score * hx * hy < bestScore) {
      bestScore = score * hx * hy;
      best = a;
    }
  }
  return best?.id;
}

const _skinTop = Color(0xFFFFF8F5);
const _skinBottom = Color(0xFFF7E4DE);
const _lipTop = Color(0xFFEDB0BA);
const _lipBottom = Color(0xFFD98597);

/// خريطة الوجه بأسلوب ناعم وأنثوي: شعر وحواجب ورموش وشفايف، ومناطق الحقن
/// نقاط صغيرة تتوهج بلون القسم لما تتأشر.
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
    Path cubic(Path path, List<double> v) =>
        path
          ..cubicTo(v[0] * w, v[1] * w, v[2] * w, v[3] * w, v[4] * w, v[5] * w);
    final ink = brand.highlight.withValues(alpha: 0.55);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.0042)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.003)
      ..strokeCap = StrokeCap.round
      ..color = ink;

    // خلفية ناعمة: دائرة وردية وقلوب ولمعات صغيرة.
    canvas.drawCircle(
      p(0.5, 0.6),
      w * 0.56,
      Paint()
        ..shader = ui.Gradient.radial(
          p(0.5, 0.6),
          w * 0.56,
          [
            brand.accent.withValues(alpha: 0.2),
            brand.accent.withValues(alpha: 0.06),
            brand.accent.withValues(alpha: 0),
          ],
          [0, 0.75, 1],
        ),
    );
    for (final (x, y, r) in const [
      (0.1, 0.18, 0.018),
      (0.92, 0.42, 0.014),
      (0.07, 0.62, 0.012),
      (0.93, 0.86, 0.017),
    ]) {
      _heart(canvas, p(x, y), w * r, brand.highlight.withValues(alpha: 0.35));
    }

    // الشعر (ورا الوجه).
    final hair = Path()..moveTo(p(0.5, 0.05).dx, p(0.5, 0.05).dy);
    cubic(hair, [0.84, 0.05, 0.93, 0.32, 0.9, 0.6]);
    cubic(hair, [0.88, 0.84, 0.94, 0.98, 0.97, 1.13]);
    hair.lineTo(p(0.03, 1.13).dx, p(0.03, 1.13).dy);
    cubic(hair, [0.06, 0.98, 0.12, 0.84, 0.1, 0.6]);
    cubic(hair, [0.07, 0.32, 0.16, 0.05, 0.5, 0.05]);
    hair.close();
    canvas.drawPath(
      hair,
      Paint()
        ..shader = ui.Gradient.linear(p(0.5, 0.05), p(0.5, 1.13), [
          brand.accent.withValues(alpha: 0.42),
          brand.accent.withValues(alpha: 0.12),
        ]),
    );
    canvas.drawPath(hair, thin..color = brand.accent.withValues(alpha: 0.7));
    // خصلات ناعمة متموجة.
    for (final sgn in [-1.0, 1.0]) {
      for (var k = 0; k < 3; k++) {
        final x0 = 0.5 + sgn * (0.33 + k * 0.035);
        final strand = Path()..moveTo(p(x0, 0.5).dx, p(x0, 0.5).dy);
        cubic(strand, [
          0.5 + sgn * (0.37 + k * 0.035),
          0.68,
          0.5 + sgn * (0.31 + k * 0.035),
          0.82,
          0.5 + sgn * (0.36 + k * 0.04),
          1.0,
        ]);
        canvas.drawPath(
          strand,
          thin..color = brand.accent.withValues(alpha: 0.45),
        );
      }
    }
    thin.color = ink;

    // الرقبة والكتفين.
    final neck = Path()..moveTo(p(0.42, 0.9).dx, p(0.42, 0.9).dy);
    neck.lineTo(p(0.415, 1.06).dx, p(0.415, 1.06).dy);
    cubic(neck, [0.36, 1.1, 0.24, 1.12, 0.16, 1.2]);
    neck.lineTo(p(0.84, 1.2).dx, p(0.84, 1.2).dy);
    cubic(neck, [0.76, 1.12, 0.64, 1.1, 0.585, 1.06]);
    neck.lineTo(p(0.58, 0.9).dx, p(0.58, 0.9).dy);
    neck.close();
    canvas.drawPath(neck, Paint()..color = _skinBottom);
    canvas.drawLine(p(0.42, 0.92), p(0.415, 1.06), line);
    canvas.drawLine(p(0.58, 0.92), p(0.585, 1.06), line);

    // الوجه.
    final face = Path()..moveTo(p(0.5, 0.17).dx, p(0.5, 0.17).dy);
    cubic(face, [0.67, 0.17, 0.79, 0.28, 0.795, 0.46]);
    cubic(face, [0.8, 0.68, 0.73, 0.85, 0.585, 0.935]);
    cubic(face, [0.54, 0.965, 0.46, 0.965, 0.415, 0.935]);
    cubic(face, [0.27, 0.85, 0.2, 0.68, 0.205, 0.46]);
    cubic(face, [0.21, 0.28, 0.33, 0.17, 0.5, 0.17]);
    face.close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = ui.Gradient.linear(p(0.5, 0.17), p(0.5, 0.98), [
          _skinTop,
          _skinBottom,
        ]),
    );
    canvas.drawPath(face, line);
    // خط الشعر الأمامي (غرّة ناعمة).
    final fringe = Path()..moveTo(p(0.24, 0.36).dx, p(0.24, 0.36).dy);
    cubic(fringe, [0.27, 0.2, 0.42, 0.15, 0.56, 0.18]);
    cubic(fringe, [0.68, 0.2, 0.76, 0.27, 0.775, 0.37]);
    canvas.drawPath(fringe, thin..color = brand.accent.withValues(alpha: 0.75));
    // غرّة جانبية ناعمة على يسار الجبين (ما تغطي منطقة الجبهة).
    final bangs = Path()..moveTo(p(0.215, 0.42).dx, p(0.215, 0.42).dy);
    cubic(bangs, [0.2, 0.26, 0.33, 0.16, 0.5, 0.165]);
    cubic(bangs, [0.4, 0.19, 0.3, 0.25, 0.265, 0.33]);
    cubic(bangs, [0.25, 0.37, 0.235, 0.4, 0.215, 0.42]);
    bangs.close();
    canvas.drawPath(
      bangs,
      Paint()
        ..shader = ui.Gradient.linear(p(0.5, 0.16), p(0.22, 0.42), [
          brand.accent.withValues(alpha: 0.75),
          brand.accent.withValues(alpha: 0.45),
        ]),
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(0.44, 0.175).dx, p(0.44, 0.175).dy)
        ..quadraticBezierTo(
          p(0.3, 0.22).dx,
          p(0.3, 0.22).dy,
          p(0.245, 0.35).dx,
          p(0.245, 0.35).dy,
        ),
      thin..color = Colors.white.withValues(alpha: 0.55),
    );
    _flower(canvas, p(0.74, 0.2), w * 0.04);
    thin.color = ink;

    // حمرة الخدود مع خطوط صغيرة لطيفة.
    for (final x in [0.33, 0.67]) {
      canvas.drawCircle(
        p(x, 0.62),
        w * 0.075,
        Paint()
          ..shader = ui.Gradient.radial(p(x, 0.62), w * 0.075, [
            _lipBottom.withValues(alpha: 0.4),
            _lipBottom.withValues(alpha: 0),
          ]),
      );
      for (var k = -1; k <= 1; k++) {
        final c = p(x + k * 0.022, 0.628);
        canvas.drawLine(
          c + Offset(w * 0.006, -w * 0.01),
          c + Offset(-w * 0.006, w * 0.01),
          Paint()
            ..strokeWidth = math.max(0.8, w * 0.0035)
            ..strokeCap = StrokeCap.round
            ..color = _lipBottom.withValues(alpha: 0.45),
        );
      }
    }

    for (final sgn in [-1.0, 1.0]) {
      final cx = 0.5 + sgn * 0.135;
      // الحاجب: شكل مدبب ناعم.
      final brow = Path()
        ..moveTo(p(0.5 + sgn * 0.055, 0.418).dx, p(0, 0.418).dy);
      brow.quadraticBezierTo(
        p(0.5 + sgn * 0.13, 0.37).dx,
        p(0, 0.37).dy,
        p(0.5 + sgn * 0.225, 0.405).dx,
        p(0, 0.405).dy,
      );
      brow.quadraticBezierTo(
        p(0.5 + sgn * 0.13, 0.388).dx,
        p(0, 0.388).dy,
        p(0.5 + sgn * 0.055, 0.428).dx,
        p(0, 0.428).dy,
      );
      brow.close();
      canvas.drawPath(
        brow,
        Paint()..color = brand.highlight.withValues(alpha: 0.5),
      );
      // العين.
      final eye = Path()
        ..moveTo(p(cx - sgn * 0.062, 0.472).dx, p(0, 0.472).dy)
        ..quadraticBezierTo(
          p(cx, 0.438).dx,
          p(0, 0.438).dy,
          p(cx + sgn * 0.065, 0.465).dx,
          p(0, 0.465).dy,
        )
        ..quadraticBezierTo(
          p(cx, 0.497).dx,
          p(0, 0.497).dy,
          p(cx - sgn * 0.062, 0.472).dx,
          p(0, 0.472).dy,
        );
      canvas.drawPath(eye, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipPath(eye);
      canvas.drawCircle(
        p(cx, 0.468),
        w * 0.024,
        Paint()
          ..shader = ui.Gradient.radial(p(cx, 0.472), w * 0.024, [
            brand.highlight.withValues(alpha: 0.6),
            brand.highlight,
          ]),
      );
      canvas.drawCircle(p(cx, 0.468), w * 0.011, Paint()..color = brand.dark);
      canvas.drawCircle(
        p(cx + 0.008, 0.461),
        w * 0.0055,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        p(cx - 0.007, 0.476),
        w * 0.0028,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.restore();
      canvas.drawPath(eye, thin);
      // خط الرموش العلوي وكم رمشة بالطرف.
      canvas.drawPath(
        Path()
          ..moveTo(p(cx - sgn * 0.062, 0.472).dx, p(0, 0.472).dy)
          ..quadraticBezierTo(
            p(cx, 0.436).dx,
            p(0, 0.436).dy,
            p(cx + sgn * 0.067, 0.463).dx,
            p(0, 0.463).dy,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, w * 0.0075)
          ..strokeCap = StrokeCap.round
          ..color = brand.dark.withValues(alpha: 0.7),
      );
      for (var k = 0; k < 3; k++) {
        final base = p(cx + sgn * (0.035 + k * 0.014), 0.447 + k * 0.005);
        canvas.drawLine(
          base,
          base + Offset(sgn * w * 0.016, -w * 0.014),
          thin..color = brand.dark.withValues(alpha: 0.55),
        );
      }
      thin.color = ink;
    }

    // الأنف.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.488, 0.49).dx, p(0.488, 0.49).dy)
        ..quadraticBezierTo(
          p(0.476, 0.565).dx,
          p(0.476, 0.565).dy,
          p(0.47, 0.598).dx,
          p(0.47, 0.598).dy,
        ),
      thin,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(0.462, 0.61).dx, p(0.462, 0.61).dy)
        ..quadraticBezierTo(
          p(0.5, 0.632).dx,
          p(0.5, 0.632).dy,
          p(0.538, 0.61).dx,
          p(0.538, 0.61).dy,
        ),
      thin,
    );

    // الشفايف.
    final upperLip = Path()
      ..moveTo(p(0.43, 0.718).dx, p(0.43, 0.718).dy)
      ..quadraticBezierTo(
        p(0.465, 0.69).dx,
        p(0.465, 0.69).dy,
        p(0.5, 0.702).dx,
        p(0.5, 0.702).dy,
      )
      ..quadraticBezierTo(
        p(0.535, 0.69).dx,
        p(0.535, 0.69).dy,
        p(0.57, 0.718).dx,
        p(0.57, 0.718).dy,
      )
      ..quadraticBezierTo(
        p(0.5, 0.726).dx,
        p(0.5, 0.726).dy,
        p(0.43, 0.718).dx,
        p(0.43, 0.718).dy,
      );
    final lowerLip = Path()
      ..moveTo(p(0.43, 0.718).dx, p(0.43, 0.718).dy)
      ..quadraticBezierTo(
        p(0.5, 0.772).dx,
        p(0.5, 0.772).dy,
        p(0.57, 0.718).dx,
        p(0.57, 0.718).dy,
      )
      ..quadraticBezierTo(
        p(0.5, 0.726).dx,
        p(0.5, 0.726).dy,
        p(0.43, 0.718).dx,
        p(0.43, 0.718).dy,
      );
    Paint lipPaint(bool on) => Paint()
      ..shader = ui.Gradient.linear(
        p(0.5, 0.69),
        p(0.5, 0.772),
        on
            ? [Color.lerp(brand.primary, Colors.white, 0.3)!, brand.primary]
            : [_lipTop, _lipBottom],
      );
    for (final (id, path) in [
      ('lip_upper', upperLip),
      ('lip_lower', lowerLip),
    ]) {
      final on = selected.contains(id);
      if (on) {
        canvas.drawPath(
          path,
          Paint()
            ..color = brand.primary.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.012),
        );
      }
      canvas.drawPath(path, lipPaint(on));
    }
    canvas.drawPath(upperLip, thin..color = _lipBottom);
    canvas.drawPath(lowerLip, thin);
    canvas.drawCircle(
      p(0.48, 0.742),
      w * 0.006,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    // زوايا ابتسامة خفيفة.
    for (final sgn in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5 + sgn * 0.072, 0.722).dx, p(0, 0.722).dy)
          ..quadraticBezierTo(
            p(0.5 + sgn * 0.085, 0.72).dx,
            p(0, 0.72).dy,
            p(0.5 + sgn * 0.088, 0.708).dx,
            p(0, 0.708).dy,
          ),
        thin..color = _lipBottom.withValues(alpha: 0.7),
      );
    }
    // قلادة ناعمة بقلب صغير.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.4, 1.075).dx, p(0, 1.075).dy)
        ..quadraticBezierTo(
          p(0.5, 1.15).dx,
          p(0, 1.15).dy,
          p(0.6, 1.075).dx,
          p(0, 1.075).dy,
        ),
      thin..color = brand.accent,
    );
    _heart(canvas, p(0.5, 1.122), w * 0.014, brand.accent);
    thin.color = ink;

    // المناطق: نقاط ناعمة، وقلب متوهج لما تتأشر.
    for (final a in faceAreas) {
      final r = a.rect(size);
      final on = selected.contains(a.id);
      final lip = a.id.startsWith('lip_');
      if (on && !lip) {
        canvas.save();
        canvas.translate(r.center.dx, r.center.dy);
        canvas.scale(1, r.height / r.width);
        canvas.drawCircle(
          Offset.zero,
          r.width * 0.62,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset.zero,
              r.width * 0.62,
              [
                brand.primary.withValues(alpha: 0.42),
                brand.highlight.withValues(alpha: 0.18),
                brand.highlight.withValues(alpha: 0),
              ],
              [0, 0.6, 1],
            ),
        );
        canvas.restore();
      }
      if (on) {
        // الشفة المؤشرة تتلون بنفسها، وباقي المناطق قلب.
        if (!lip) {
          _heart(
            canvas,
            r.center,
            w * 0.02,
            brand.primary,
            stroke: Colors.white,
          );
        }
      } else {
        final dot = w * 0.012;
        canvas.drawCircle(
          r.center,
          dot,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          r.center,
          dot,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, w * 0.003)
            ..color = brand.highlight.withValues(alpha: 0.55),
        );
        canvas.drawCircle(
          r.center,
          w * 0.0035,
          Paint()..color = brand.highlight.withValues(alpha: 0.6),
        );
      }
      if (on && showDoses && (doses[a.id] ?? '').isNotEmpty) {
        _pill(
          canvas,
          doses[a.id]!,
          lip
              ? Offset(r.right + w * 0.06, r.center.dy)
              : r.center + Offset(0, -w * 0.04),
          w * 0.024,
          brand,
        );
      }
    }
    // نجمة لمعة.
    _star(canvas, p(0.86, 0.14), w * 0.025, brand.accent);
    _star(canvas, p(0.9, 0.2), w * 0.012, brand.accent);
  }

  void _heart(Canvas canvas, Offset c, double r, Color color, {Color? stroke}) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(
        c.dx - r * 1.3,
        c.dy + r * 0.1,
        c.dx - r * 0.9,
        c.dy - r * 1.05,
        c.dx,
        c.dy - r * 0.35,
      )
      ..cubicTo(
        c.dx + r * 0.9,
        c.dy - r * 1.05,
        c.dx + r * 1.3,
        c.dy + r * 0.1,
        c.dx,
        c.dy + r * 0.9,
      )
      ..close();
    if (stroke != null) {
      canvas.drawPath(
        path.shift(Offset(0, r * 0.15)),
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.22
          ..color = stroke,
      );
    }
  }

  /// وردة صغيرة بالشعر: خمس بتلات بلون القسم ووسط شامبين.
  void _flower(Canvas canvas, Offset c, double r) {
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final pc = c + Offset(math.cos(a), math.sin(a)) * r * 0.55;
      canvas.drawCircle(
        pc,
        r * 0.48,
        Paint()
          ..shader = ui.Gradient.radial(pc, r * 0.48, [
            Color.lerp(brand.highlight, Colors.white, 0.45)!,
            brand.highlight,
          ]),
      );
    }
    canvas.drawCircle(c, r * 0.32, Paint()..color = brand.accent);
    canvas.drawCircle(
      c + Offset(-r * 0.1, -r * 0.1),
      r * 0.1,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final k = r * 0.22;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
        ..close(),
      Paint()..color = color,
    );
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
