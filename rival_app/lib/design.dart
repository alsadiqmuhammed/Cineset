import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'brand.dart';
import 'elements.dart';
import 'models.dart';
import 'render.dart';

export 'elements.dart';

/// قوالب الهوية الجاهزة: صورة PNG شفافة بشبابيك تبين منها الصور.
/// مكان كل شباك مقاس من شفافية القالب نفسه.
class DesignTemplate {
  final String id, label, asset;
  final PostFormat format;
  final List<Rect> slots;
  const DesignTemplate(
    this.id,
    this.label,
    this.asset,
    this.format,
    this.slots,
  );

  int get photos => slots.length;
}

const _t = 'assets/templates';

const dentalTemplates = [
  DesignTemplate(
    'dental_post_2',
    'بوست · صورتين',
    '$_t/dental_post_2.png',
    PostFormat.portrait,
    [Rect.fromLTRB(555, 240, 980, 1050), Rect.fromLTRB(100, 240, 525, 1050)],
  ),
  DesignTemplate(
    'dental_post_1',
    'بوست · صورة',
    '$_t/dental_post_1.png',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 240, 970, 1050)],
  ),
  DesignTemplate(
    'dental_story_2',
    'ستوري · صورتين',
    '$_t/dental_story_2.png',
    PostFormat.story,
    [Rect.fromLTRB(555, 370, 980, 1420), Rect.fromLTRB(100, 370, 525, 1420)],
  ),
  DesignTemplate(
    'dental_story_1',
    'ستوري · صورة',
    '$_t/dental_story_1.png',
    PostFormat.story,
    [Rect.fromLTRB(110, 370, 970, 1420)],
  ),
];

const beautyTemplates = [
  DesignTemplate(
    'beauty_post_2',
    'بوست · صورتين',
    '$_t/beauty_post_2.png',
    PostFormat.portrait,
    [Rect.fromLTRB(558, 320, 970, 1050), Rect.fromLTRB(110, 250, 522, 980)],
  ),
  DesignTemplate(
    'beauty_post_1',
    'بوست · صورة',
    '$_t/beauty_post_1.png',
    PostFormat.portrait,
    [Rect.fromLTRB(160, 250, 920, 1050)],
  ),
  DesignTemplate(
    'beauty_story_2',
    'ستوري · صورتين',
    '$_t/beauty_story_2.png',
    PostFormat.story,
    [Rect.fromLTRB(558, 450, 970, 1420), Rect.fromLTRB(110, 380, 522, 1350)],
  ),
  DesignTemplate(
    'beauty_story_1',
    'ستوري · صورة',
    '$_t/beauty_story_1.png',
    PostFormat.story,
    [Rect.fromLTRB(140, 380, 940, 1420)],
  ),
];

List<DesignTemplate> templatesFor(Section s) =>
    s == Section.dental ? dentalTemplates : beautyTemplates;

/// أي صورة بالشباك.
enum Which {
  before('قبل'),
  after('بعد');

  final String label;
  const Which(this.label);
}

class SlotFill {
  Which which;
  Framing framing;
  SlotFill(this.which, [this.framing = const Framing()]);

  SlotFill copy() => SlotFill(which, framing);
}

/// أدوات التعديل. كلها تنرسم بطبقة وحدة فوق الصور وتحت القالب،
/// فالممحاة تمسح أي إضافة بس ما تمس الصور ولا القالب.
enum MarkKind {
  pen('رسم', 'draw'),
  arrow('سهم', 'arrow'),
  circle('دائرة', 'circle'),
  rect('مربع', 'rect'),
  blurRect('تضبيب', 'blur'),
  blurBrush('تضبيب حر', 'blurBrush'),
  eraser('ممحاة', 'eraser');

  final String label, key;
  const MarkKind(this.label, this.key);

  bool get freehand =>
      this == MarkKind.pen ||
      this == MarkKind.eraser ||
      this == MarkKind.blurBrush;
}

class Mark {
  final MarkKind kind;
  final List<Offset> points;
  final Color color;

  /// عرض الخط (أو فرشاة التضبيب) بنسبة من عرض التصميم.
  final double width;
  Mark(this.kind, this.points, this.color, this.width);
}

class DesignSpec {
  final Brand brand;
  final Size size;
  final List<Rect> slots;
  final List<SlotFill> fills;
  final Map<Which, (ui.Image, Photo)> photos;
  final ui.Image? template;
  final ui.Image? overlay;
  final BrandFrame? frame;
  final bool labels;

  /// شارات قبل/بعد جوّه الشباك (مع القوالب والإطار) أو فوق.
  final bool labelsAtBottom;
  final List<Mark> marks;

  /// نصوص وصور تتحرك فوق كل شي (اسم الطبيب، توقيع...).
  final List<DesignElement> elements;

  const DesignSpec({
    required this.brand,
    required this.size,
    required this.slots,
    required this.fills,
    required this.photos,
    this.template,
    this.overlay,
    this.frame,
    this.labels = true,
    this.labelsAtBottom = false,
    this.marks = const [],
    this.elements = const [],
  });

  DesignSpec copyWith({
    List<SlotFill>? fills,
    bool clearTemplate = false,
    bool clearOverlay = false,
    bool clearFrame = false,
    bool? labels,
    List<Mark>? marks,
    List<DesignElement>? elements,
  }) => DesignSpec(
    brand: brand,
    size: size,
    slots: slots,
    fills: fills ?? this.fills,
    photos: photos,
    template: clearTemplate ? null : template,
    overlay: clearOverlay ? null : overlay,
    frame: clearFrame ? null : frame,
    labels: labels ?? this.labels,
    labelsAtBottom: labelsAtBottom,
    marks: marks ?? this.marks,
    elements: elements ?? this.elements,
  );

  /// أماكن شارات قبل/بعد (حتى اسم الطبيب ما يركب عليها).
  List<Rect> get labelRects => [
    if (labels)
      for (var i = 0; i < slots.length && i < fills.length; i++)
        labelRect(
          labelsAtBottom ? slots[i].deflate(size.width * 0.01) : slots[i],
          fills[i].which.label,
          size.width,
          align: labelsAtBottom ? Alignment.bottomCenter : Alignment.topCenter,
        ),
  ];
}

/// أماكن مقترحة لاسم الطبيب (بالترتيب): تحت الشعار بالإطار، وبأعلى الصور
/// بالقوالب، وإلا تحت أو فوق التصميم.
List<Offset> nameSpots(
  Size s,
  List<Rect> slots, {
  required bool templated,
  required bool framed,
}) {
  double y(double px) => px / s.height;
  final unit = math.min(s.width, s.height);
  final all = slots.reduce((a, b) => a.expandToInclude(b));
  final gap = s.width * 0.045;
  return [
    if (!templated && framed) Offset(0.5, y(unit * 0.23)),
    // القوالب بيها كتابة تحت الشبابيك وفوقها، فالاسم بأعلى الصورة
    // (شارات قبل/بعد تكون بأسفلها).
    if (templated) Offset(0.5, y(all.top + gap * 1.3)),
    Offset(0.5, 1 - y(gap * 1.4)),
    Offset(0.5, y(gap * 1.4)),
    Offset(0.5, y(all.center.dy)),
  ];
}

/// عنصر اسم الطبيب بألوان الهوية، بمكان ما يركب على شارات قبل/بعد.
DesignElement doctorNameElement(String name, Brand b) => DesignElement.text(
  name,
  role: ElementRole.doctor,
  color: b.dark,
  pill: true,
  pillColor: b.accent,
  size: 0.034,
);

/// يرسم التصميم كامل. نفس الدالة للمعاينة الحيّة وللتصدير.
/// الترتيب: الخلفية ← الصور ← طبقة الإضافات (تضبيب، أشكال، رسم، ممحاة)
/// ← القالب/الإطار ← شارات قبل وبعد.
void paintDesign(Canvas canvas, DesignSpec s) {
  final full = Offset.zero & s.size;
  canvas.drawRect(
    full,
    Paint()..color = s.template == null ? s.brand.accent : s.brand.bg,
  );

  void photos(Canvas c) {
    for (var i = 0; i < s.slots.length && i < s.fills.length; i++) {
      final fill = s.fills[i];
      final p = s.photos[fill.which];
      if (p == null) continue;
      paintPhoto(c, s.slots[i], p.$1, p.$2, fill.framing);
    }
  }

  photos(canvas);

  if (s.marks.isNotEmpty) {
    canvas.saveLayer(full, Paint());
    for (final m in s.marks) {
      _paintMark(canvas, m, s, photos);
    }
    canvas.restore();
  }

  if (s.template != null) {
    canvas.drawImageRect(
      s.template!,
      Rect.fromLTWH(
        0,
        0,
        s.template!.width.toDouble(),
        s.template!.height.toDouble(),
      ),
      full,
      Paint()..filterQuality = FilterQuality.high,
    );
  }
  paintOverlay(canvas, s.size, s.overlay);
  if (s.frame != null) paintBrandFrame(canvas, s.size, s.frame!);

  if (s.labels) {
    for (var i = 0; i < s.slots.length && i < s.fills.length; i++) {
      final which = s.fills[i].which;
      final cell = s.slots[i];
      final templated = s.labelsAtBottom;
      paintLabel(
        canvas,
        templated ? cell.deflate(s.size.width * 0.01) : cell,
        which.label,
        s.size.width,
        bg: which == Which.after ? s.brand.primary : s.brand.dark,
        fg: const Color(0xFFFFFFFF),
        align: templated ? Alignment.bottomCenter : Alignment.topCenter,
      );
    }
  }
  paintElements(canvas, s.size, s.elements);
}

void _paintMark(
  Canvas canvas,
  Mark m,
  DesignSpec s,
  void Function(Canvas) photos,
) {
  final w = m.width * s.size.width;
  final stroke = Paint()
    ..color = m.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  switch (m.kind) {
    case MarkKind.pen:
      canvas.drawPath(_smooth(m.points), stroke);
    case MarkKind.eraser:
      canvas.drawPath(
        _smooth(m.points),
        stroke
          ..blendMode = BlendMode.clear
          ..strokeWidth = w * 2.5,
      );
    case MarkKind.arrow:
      if (m.points.length < 2) return;
      final a = m.points.first, b = m.points.last;
      final d = b - a;
      if (d.distance < 1) return;
      final head = math.min(d.distance * 0.45, w * 5);
      final dir = d / d.distance;
      final base = b - dir * head * 0.8;
      canvas.drawLine(a, base, stroke);
      final n = Offset(-dir.dy, dir.dx);
      canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(
            (b - dir * head + n * head * 0.55).dx,
            (b - dir * head + n * head * 0.55).dy,
          )
          ..lineTo(
            (b - dir * head - n * head * 0.55).dx,
            (b - dir * head - n * head * 0.55).dy,
          )
          ..close(),
        Paint()
          ..color = m.color
          ..isAntiAlias = true,
      );
    case MarkKind.circle:
      if (m.points.length < 2) return;
      canvas.drawOval(Rect.fromPoints(m.points.first, m.points.last), stroke);
    case MarkKind.rect:
      if (m.points.length < 2) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(m.points.first, m.points.last),
          Radius.circular(w * 1.5),
        ),
        stroke,
      );
    case MarkKind.blurRect:
    case MarkKind.blurBrush:
      final Path area;
      if (m.kind == MarkKind.blurRect) {
        if (m.points.length < 2) return;
        area = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromPoints(m.points.first, m.points.last),
              Radius.circular(s.size.width * 0.012),
            ),
          );
      } else {
        area = _brushArea(m.points, w * 2.5);
      }
      final sigma = s.size.width * 0.018;
      final bounds = area.getBounds().inflate(sigma * 3);
      canvas.save();
      canvas.clipPath(area);
      canvas.saveLayer(
        bounds,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
      );
      photos(canvas);
      canvas.restore();
      canvas.restore();
  }
}

/// خط ناعم بين النقاط (منتصفات بمنحنيات).
Path _smooth(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) {
    path.lineTo(pts.first.dx + 0.1, pts.first.dy);
    return path;
  }
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = (pts[i] + pts[i + 1]) / 2;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// منطقة فرشاة التضبيب: دوائر على طول المسار.
Path _brushArea(List<Offset> pts, double r) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    path.addOval(Rect.fromCircle(center: pts[i], radius: r));
    if (i == 0) continue;
    final a = pts[i - 1], b = pts[i];
    final steps = ((b - a).distance / (r * 0.5)).ceil();
    for (var k = 1; k < steps; k++) {
      path.addOval(
        Rect.fromCircle(center: Offset.lerp(a, b, k / steps)!, radius: r),
      );
    }
  }
  return path;
}

Future<ui.Image> renderDesign(DesignSpec s, {double scale = 1}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  paintDesign(canvas, s);
  return recorder.endRecording().toImage(
    (s.size.width * scale).round(),
    (s.size.height * scale).round(),
  );
}

/// أقل تقريب يخلّي الصورة تملأ شباكها.
Framing fitFraming(Rect cell, ui.Image img, Photo p, Framing f) {
  final z = coverZoom(
    cell,
    Size(img.width.toDouble(), img.height.toDouble()),
    p,
    f,
  );
  return f.copyWith(zoom: math.max(1.0, z).clamp(0.3, 4.0));
}
