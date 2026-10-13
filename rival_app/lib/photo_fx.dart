import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// شكل شباك الصورة لما ينقص بالرسم نفسه (مو بفتحة القالب)، حتى الشبابيك
/// تكدر تتداخل: دائرة فوق صورة، أو سنّين متراكبين.
enum SlotShape { rect, oval, tooth, drop }

/// قناع الشباك: الشكل، وحافة ناعمة تذوب بالخلفية، وتدرّج يخلّي الصورة
/// تختفي تدريجياً (فتذوب "بعد" فوق "قبل" بدون أي حد).
class SlotMask {
  final SlotShape shape;

  /// تدوير زوايا المستطيل (بكسلات التصميم).
  final double radius;

  /// نعومة الحافة (بكسلات التصميم). صفر = حافة حادة.
  final double feather;

  /// تدرّج الظهور: شفاف عند [fadeFrom] ويكمل لحد [fadeTo] (نسبة للشباك)،
  /// والانتقال بين [fadeStart] و[fadeEnd] من طول الخط.
  final Alignment? fadeFrom, fadeTo;
  final double fadeStart, fadeEnd;

  const SlotMask({
    this.shape = SlotShape.rect,
    this.radius = 0,
    this.feather = 0,
    this.fadeFrom,
    this.fadeTo,
    this.fadeStart = 0,
    this.fadeEnd = 1,
  });

  bool get soft => feather > 0 || fadeFrom != null;
}

// الأشكال بمربع وحدة (0..1)، نفس الأرقام اللي ترسم فتحات القوالب.
const _tooth = [
  [0.5, 0.12],
  [0.38, 0.0, 0.05, 0.0, 0.04, 0.28],
  [0.03, 0.5, 0.15, 0.62, 0.2, 0.8],
  [0.24, 0.96, 0.33, 1.0, 0.36, 0.9],
  [0.4, 0.78, 0.43, 0.64, 0.5, 0.64],
  [0.57, 0.64, 0.6, 0.78, 0.64, 0.9],
  [0.67, 1.0, 0.76, 0.96, 0.8, 0.8],
  [0.85, 0.62, 0.97, 0.5, 0.96, 0.28],
  [0.95, 0.0, 0.62, 0.0, 0.5, 0.12],
];
const _drop = [
  [0.5, 0.0],
  [0.62, 0.2, 1.0, 0.45, 1.0, 0.68],
  [1.0, 0.88, 0.78, 1.0, 0.5, 1.0],
  [0.22, 1.0, 0.0, 0.88, 0.0, 0.68],
  [0.0, 0.45, 0.38, 0.2, 0.5, 0.0],
];

Path _unitPath(List<List<double>> d, Rect r) {
  Offset p(double x, double y) =>
      Offset(r.left + x * r.width, r.top + y * r.height);
  final first = p(d[0][0], d[0][1]);
  final path = Path()..moveTo(first.dx, first.dy);
  for (final c in d.skip(1)) {
    final a = p(c[0], c[1]), b = p(c[2], c[3]), e = p(c[4], c[5]);
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
  }
  return path..close();
}

Path slotPath(SlotMask m, Rect r) => switch (m.shape) {
  SlotShape.rect =>
    Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(m.radius))),
  SlotShape.oval => Path()..addOval(r),
  SlotShape.tooth => _unitPath(_tooth, r),
  SlotShape.drop => _unitPath(_drop, r),
};

/// يرسم [photo] (اللي يرسم الصورة بالشباك) من خلال القناع.
void paintMasked(
  Canvas canvas,
  Rect cell,
  SlotMask m,
  void Function(Canvas) photo,
) {
  canvas.saveLayer(cell, Paint());
  photo(canvas);
  // الشكل: الحافة الناعمة تنكمش لداخل الشباك حتى ما تنقص فجأة على حدّه.
  final inner = m.feather > 0 ? cell.deflate(m.feather * 2.5) : cell;
  // القناع طبقة كاملة تندمج بـ dstIn: اللي برّه الشكل (شفاف بالطبقة)
  // ينمسح من الصورة، مو بس اللي ينرسم عليه.
  final shape = Paint()..isAntiAlias = true;
  if (m.feather > 0) {
    shape.maskFilter = MaskFilter.blur(BlurStyle.normal, m.feather);
  }
  canvas.saveLayer(cell, Paint()..blendMode = BlendMode.dstIn);
  canvas.drawPath(slotPath(m, inner), shape);
  canvas.restore();
  final from = m.fadeFrom, to = m.fadeTo;
  if (from != null && to != null) {
    canvas.drawRect(
      cell,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          from.withinRect(cell),
          to.withinRect(cell),
          const [Color(0x00000000), Color(0xFF000000)],
          [m.fadeStart, m.fadeEnd],
        ),
    );
  }
  canvas.restore();
}

/// تعديل الإضاءة والألوان لصورة. كل القيم من -1 لـ 1، والصفر بدون تغيير.
class PhotoAdjust {
  final double brightness, contrast, saturation, warmth, tint, fade;
  const PhotoAdjust({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.tint = 0,
    this.fade = 0,
  });

  static const none = PhotoAdjust();

  bool get isNone =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0 &&
      tint == 0 &&
      fade == 0;

  PhotoAdjust copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? tint,
    double? fade,
  }) => PhotoAdjust(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
    tint: tint ?? this.tint,
    fade: fade ?? this.fade,
  );

  /// مصفوفة 4×5 لـ ColorFilter.matrix.
  List<double> get matrix {
    var m = _identity();
    // التشبع (أوزان الإضاءة القياسية).
    final s = 1 + saturation;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    m = _mul([
      lr * (1 - s) + s,
      lg * (1 - s),
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg * (1 - s) + s,
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg * (1 - s),
      lb * (1 - s) + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ], m);
    // الدفء (أحمر/أزرق) والصبغة (أخضر/وردي).
    m = _mul([
      1,
      0,
      0,
      0,
      warmth * 22 + tint * 8,
      0,
      1,
      0,
      0,
      -tint * 18,
      0,
      0,
      1,
      0,
      -warmth * 22 + tint * 8,
      0,
      0,
      0,
      1,
      0,
    ], m);
    // التباين حول المنتصف، والإضاءة إزاحة.
    final k = math.pow(2, contrast * 0.8).toDouble();
    final off = 128 * (1 - k) + brightness * 70;
    m = _mul([
      k,
      0,
      0,
      0,
      off,
      0,
      k,
      0,
      0,
      off,
      0,
      0,
      k,
      0,
      off,
      0,
      0,
      0,
      1,
      0,
    ], m);
    // البهتان: يرفع الأسود ويخفّض الأبيض (مظهر ناعم مثل الفلم).
    if (fade != 0) {
      final f = fade.clamp(-1.0, 1.0) * 0.18;
      m = _mul([
        1 - f,
        0,
        0,
        0,
        f * 160,
        0,
        1 - f,
        0,
        0,
        f * 160,
        0,
        0,
        1 - f,
        0,
        f * 160,
        0,
        0,
        0,
        1,
        0,
      ], m);
    }
    return m;
  }

  ColorFilter? get filter => isNone ? null : ColorFilter.matrix(matrix);

  static List<double> _identity() => [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// a × b (كلها 4×5 مع صف خامس ضمني 0 0 0 0 1).
  static List<double> _mul(List<double> a, List<double> b) {
    final r = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var v = j == 4 ? a[i * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[i * 5 + k] * b[k * 5 + j];
        }
        r[i * 5 + j] = v;
      }
    }
    return r;
  }

  /// تحسين تلقائي: يقرأ متوسط الإضاءة والتباين وتوازن الألوان بالصورة
  /// ويقرّبها لصورة متوازنة (بدون مبالغة).
  static Future<PhotoAdjust> auto(ui.Image img) async {
    // نصغّر قبل القراءة: ٦٤ بكسل تكفي للإحصاء.
    const side = 64;
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      const Rect.fromLTWH(0, 0, side + 0.0, side + 0.0),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final small = await rec.endRecording().toImage(side, side);
    final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    if (data == null) return none;
    return fromPixels(data.buffer.asUint8List());
  }

  static PhotoAdjust fromPixels(Uint8List px) {
    var n = 0;
    double sr = 0, sg = 0, sb = 0, sl = 0, sl2 = 0;
    for (var i = 0; i + 3 < px.length; i += 4) {
      final r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255;
      final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      sr += r;
      sg += g;
      sb += b;
      sl += l;
      sl2 += l * l;
      n++;
    }
    if (n == 0) return none;
    final mean = sl / n;
    final sd = math.sqrt(math.max(0, sl2 / n - mean * mean));
    final r = sr / n, g = sg / n, b = sb / n;
    double clamp(double v, double lim) => v.clamp(-lim, lim);
    return PhotoAdjust(
      brightness: clamp((0.52 - mean) * 1.6, 0.45),
      contrast: clamp((0.22 - sd) * 3, 0.4),
      // يعادل اللون المائل (أزرق أو أصفر) بشوية.
      warmth: clamp((b - r + 0.12) * 2.0, 0.35),
      tint: clamp((g - (r + b) / 2 + 0.03) * 2.5, 0.3),
      saturation: 0.08,
    );
  }
}
