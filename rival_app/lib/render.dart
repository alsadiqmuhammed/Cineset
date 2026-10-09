import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'elements.dart';
import 'models.dart';

enum PostFormat {
  portrait(1080, 1350, 'منشور 4:5'),
  story(1080, 1920, 'ستوري 9:16'),
  square(1080, 1080, 'مربع');

  final int width, height;
  final String label;
  const PostFormat(this.width, this.height, this.label);
  Size get size => Size(width.toDouble(), height.toDouble());
}

enum Layout {
  sideBySide('جنب بعض'),
  stacked('فوق وتحت');

  final String label;
  const Layout(this.label);
}

/// تكبير وإزاحة عمودية يتطبقون على الصورتين بنفس المقدار حتى يبقون متطابقين.
///
/// [offsetX] و[offsetY] نسبة من عرض/ارتفاع الخلية، و[rotation] بالراديان.
class Framing {
  final double zoom, offsetX, offsetY, rotation;
  const Framing({
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotation = 0,
  });

  Framing copyWith({
    double? zoom,
    double? offsetX,
    double? offsetY,
    double? rotation,
  }) => Framing(
    zoom: zoom ?? this.zoom,
    offsetX: offsetX ?? this.offsetX,
    offsetY: offsetY ?? this.offsetY,
    rotation: rotation ?? this.rotation,
  );
}

final _cache = <String, ui.Image>{};

/// صور الحالات بالذاكرة: آخر ٦ بس (صورة ٢٤٠٠ بكسل حوالي ٢٠ ميغا).
/// القديمة ما تنمسح غصباً (ممكن شاشة بعدها تستخدمها)، بس تنترك للذاكرة.
const _maxPhotos = 6;
final _recent = <String>[];

/// الصورة ما موجودة على الجهاز (بعدها تنزل من جهاز ثاني، أو انحذفت).
class PhotoMissing implements Exception {
  final String path;
  const PhotoMissing(this.path);
  @override
  String toString() => 'الصورة بعدها ما نزلت على هذا الجهاز';
}

Future<ui.Image> loadImage(String path) async {
  final cached = _cache[path];
  if (cached != null) {
    _recent
      ..remove(path)
      ..add(path);
    return cached;
  }
  final file = File(path);
  if (!await file.exists()) throw PhotoMissing(path);
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final image = (await codec.getNextFrame()).image;
  _cache[path] = image;
  _recent.add(path);
  while (_recent.length > _maxPhotos) {
    _cache.remove(_recent.removeAt(0));
  }
  return image;
}

void evictImage(String path) => _cache.remove(path)?.dispose();

void clearImageCache() {
  _cache.clear();
  _recent.clear();
}

/// صورة من ملفات التطبيق (الشعارات).
Future<ui.Image> loadAssetImage(String asset) async {
  final cached = _cache[asset];
  if (cached != null) return cached;
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final image = (await codec.getNextFrame()).image;
  _cache[asset] = image;
  return image;
}

/// تحويل من بكسلات الصورة لمكانها داخل الخلية: نقطتا المحاذاة تقعان بنفس
/// المكان بكل الخلايا (منتصفهما بالوسط، والخط بينهما أفقي وبنفس الطول).
/// بدون نقاط: الصورة تملأ الخلية من الوسط.
class CellMapping {
  final Offset target, mid;
  final double scale, angle;
  const CellMapping(this.target, this.mid, this.scale, this.angle);

  factory CellMapping.of(Rect cell, Size image, Photo p, Framing f) {
    final target = Offset(
      cell.left + cell.width * (0.5 + f.offsetX),
      cell.top + cell.height * (0.5 + f.offsetY),
    );
    if (!p.aligned) {
      return CellMapping(
        target,
        Offset(image.width / 2, image.height / 2),
        math.max(cell.width / image.width, cell.height / image.height) * f.zoom,
        f.rotation,
      );
    }
    final left = p.a!.dx <= p.b!.dx ? p.a! : p.b!;
    final right = left == p.a ? p.b! : p.a!;
    final d = right - left;
    return CellMapping(
      target,
      (left + right) / 2,
      cell.width * 0.42 * f.zoom / math.max(d.distance, 1.0),
      -math.atan2(d.dy, d.dx) + f.rotation,
    );
  }

  Offset map(Offset p) {
    final v = (p - mid) * scale;
    final c = math.cos(angle), s = math.sin(angle);
    return target + Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }
}

/// أقل تقريب يخلّي الصورة تغطي الخلية كلها بدون حواف سودة.
/// (الإزاحة والدوران من [f]؛ التقريب يتجاهله.)
double coverZoom(Rect cell, Size image, Photo p, Framing f) {
  final m = CellMapping.of(cell, image, p, f.copyWith(zoom: 1));
  final c = math.cos(-m.angle), s = math.sin(-m.angle);
  var zoom = 0.0;
  for (final corner in [
    cell.topLeft,
    cell.topRight,
    cell.bottomLeft,
    cell.bottomRight,
  ]) {
    final d = corner - m.target;
    // موضع الزاوية بالصورة عند تقريب 1، نسبةً لنقطة المنتصف.
    final v = Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c) / m.scale;
    for (final (comp, mid, max) in [
      (v.dx, m.mid.dx, image.width),
      (v.dy, m.mid.dy, image.height),
    ]) {
      if (comp > 0) zoom = math.max(zoom, comp / math.max(max - mid, 1e-6));
      if (comp < 0) zoom = math.max(zoom, -comp / math.max(mid, 1e-6));
    }
  }
  return zoom;
}

void paintPhoto(Canvas canvas, Rect cell, ui.Image img, Photo p, Framing f) {
  final m = CellMapping.of(
    cell,
    Size(img.width.toDouble(), img.height.toDouble()),
    p,
    f,
  );
  canvas.save();
  canvas.clipRect(cell);
  canvas.drawRect(cell, Paint()..color = const Color(0xFF0B0C0D));
  canvas.translate(m.target.dx, m.target.dy);
  canvas.rotate(m.angle);
  canvas.scale(m.scale);
  canvas.translate(-m.mid.dx, -m.mid.dy);
  canvas.drawImage(
    img,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
}

/// مكان شارة "قبل" / "بعد" (بدون رسم)، حتى العناصر الثانية تتجنبها.
Rect labelRect(
  Rect cell,
  String text,
  double unit, {
  Alignment align = Alignment.topCenter,
}) {
  final para = _paragraph(
    text,
    unit * 0.04,
    const Color(0xFFFFFFFF),
    FontWeight.w800,
    cell.width,
  );
  final r = _labelRect(cell, para, unit, align);
  para.dispose();
  return r;
}

Rect _labelRect(Rect cell, ui.Paragraph para, double unit, Alignment align) {
  final w = para.longestLine + unit * 0.07;
  final h = para.height + unit * 0.022;
  final margin = unit * 0.05;
  final cx = switch (align.x) {
    < 0 => cell.left + margin + w / 2,
    > 0 => cell.right - margin - w / 2,
    _ => cell.center.dx,
  };
  final cy = align.y < 0
      ? cell.top + margin + h / 2
      : cell.bottom - margin - h / 2;
  return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
}

/// شارة "قبل" / "بعد". قبل: غامقة، بعد: بلون القسم.
void paintLabel(
  Canvas canvas,
  Rect cell,
  String text,
  double unit, {
  required Color bg,
  required Color fg,
  Alignment align = Alignment.topCenter,
}) {
  final para = _paragraph(text, unit * 0.04, fg, FontWeight.w800, cell.width);
  final pill = _labelRect(cell, para, unit, align);
  final h = pill.height;
  canvas.drawRRect(
    RRect.fromRectAndRadius(pill, Radius.circular(h / 2)),
    Paint()..color = bg,
  );
  canvas.drawParagraph(
    para,
    Offset(pill.center.dx - para.width / 2, pill.top + (h - para.height) / 2),
  );
}

ui.Paragraph _paragraph(
  String text,
  double size,
  Color color,
  FontWeight weight,
  double width,
) {
  ui.Paragraph build(double w) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              fontFamily: kFontUi,
              fontSize: size,
              fontWeight: weight,
              maxLines: 1,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color, fontFamily: kFontUi))
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: w));
  }

  // نقيس عرض السطر الفعلي أولاً، وبعدين نبني فقرة بنفس العرض حتى نوسّط بدقة.
  final measured = build(width);
  final w = measured.longestLine.ceilToDouble() + 1;
  measured.dispose();
  return build(w);
}

void paintOverlay(Canvas canvas, Size size, ui.Image? overlay) {
  if (overlay == null) return;
  canvas.drawImageRect(
    overlay,
    Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.high,
  );
}

/// إطار الهوية المدمج: تدرّج فوق وجوّه، إطار داخلي رفيع، الشعار المعكوس فوق،
/// نجوم اللمعة، وشارة باسم الطبيب جوّه.
class BrandFrame {
  final Brand brand;
  final ui.Image logo; // النسخة المعكوسة (للخلفيات الغامقة)
  final String caption;
  const BrandFrame(this.brand, this.logo, this.caption);
}

void paintBrandFrame(Canvas canvas, Size size, BrandFrame f) {
  final w = size.width, h = size.height;
  final unit = math.min(w, h);
  final shade = f.brand.dark;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h * 0.2),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.2), [
        shade.withValues(alpha: 0.6),
        shade.withValues(alpha: 0),
      ]),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, h * 0.76, w, h * 0.24),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.76), Offset(0, h), [
        shade.withValues(alpha: 0),
        shade.withValues(alpha: 0.7),
      ]),
  );
  final inset = unit * 0.035;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2),
      Radius.circular(unit * 0.045),
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.0025
      ..color = f.brand.accent.withValues(alpha: 0.85),
  );
  // الشعار بالنص فوق، ارتفاعه حوالي ١٢٠ بكسل من ١٠٨٠.
  final logoH = unit * 0.11;
  final logoW = logoH * f.logo.width / f.logo.height;
  canvas.drawImageRect(
    f.logo,
    Rect.fromLTWH(0, 0, f.logo.width.toDouble(), f.logo.height.toDouble()),
    Rect.fromLTWH((w - logoW) / 2, inset * 1.9, logoW, logoH),
    Paint()..filterQuality = FilterQuality.high,
  );
  final star = Paint()..color = f.brand.accent;
  _sparkle(canvas, Offset(w - inset * 2.6, inset * 2.8), unit * 0.018, star);
  _sparkle(canvas, Offset(w - inset * 3.6, inset * 3.9), unit * 0.009, star);
  _sparkle(canvas, Offset(inset * 2.4, h - inset * 2.4), unit * 0.011, star);
  if (f.caption.isNotEmpty) {
    paintLabel(
      canvas,
      Rect.fromLTWH(0, 0, w, h - inset),
      f.caption,
      unit * 0.85,
      bg: f.brand.accent,
      fg: f.brand.dark,
      align: Alignment.bottomCenter,
    );
  }
}

/// نجمة لمعة رباعية.
void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
  final k = r * 0.22;
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, paint);
}

class CompositeSpec {
  final ui.Image before, after;
  final Photo beforePhoto, afterPhoto;
  final Brand brand;
  final PostFormat format;
  final Layout layout;
  final Framing framing;
  final ui.Image? overlay;
  final BrandFrame? frame;
  final bool labels;

  const CompositeSpec({
    required this.before,
    required this.after,
    required this.beforePhoto,
    required this.afterPhoto,
    this.brand = dental,
    this.format = PostFormat.portrait,
    this.layout = Layout.sideBySide,
    this.framing = const Framing(),
    this.overlay,
    this.frame,
    this.labels = true,
  });
}

(Rect, Rect) cellsFor(Size size, Layout layout) {
  final gap = size.width * 0.006;
  return layout == Layout.sideBySide
      ? (
          Rect.fromLTWH(0, 0, (size.width - gap) / 2, size.height),
          Rect.fromLTWH(
            (size.width + gap) / 2,
            0,
            (size.width - gap) / 2,
            size.height,
          ),
        )
      : (
          Rect.fromLTWH(0, 0, size.width, (size.height - gap) / 2),
          Rect.fromLTWH(
            0,
            (size.height + gap) / 2,
            size.width,
            (size.height - gap) / 2,
          ),
        );
}

/// صورة "قبل وبعد" بخليتين. نفس الدالة للمعاينة (scale صغير) وللتصدير (scale = 1).
Future<ui.Image> renderComposite(CompositeSpec s, {double scale = 1}) {
  final size = s.format.size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  final (first, second) = cellsFor(size, s.layout);
  canvas.drawRect(Offset.zero & size, Paint()..color = s.brand.accent);
  // بالعربي "قبل" تكون باليمين (أو بالأعلى).
  final side = s.layout == Layout.sideBySide;
  final beforeCell = side ? second : first;
  final afterCell = side ? first : second;
  paintPhoto(canvas, beforeCell, s.before, s.beforePhoto, s.framing);
  paintPhoto(canvas, afterCell, s.after, s.afterPhoto, s.framing);
  if (s.labels) {
    // مع إطار الهوية: الشعار فوق بالنص، فالشارات تنزل لجوّه (أو للزاوية).
    final align = s.frame == null
        ? Alignment.topCenter
        : side
        ? Alignment.bottomCenter
        : Alignment.topRight;
    final lift = s.frame != null && side ? size.height * 0.08 : 0.0;
    paintLabel(
      canvas,
      Rect.fromLTRB(
        beforeCell.left,
        beforeCell.top,
        beforeCell.right,
        beforeCell.bottom - lift,
      ).deflate(s.frame == null ? 0 : size.width * 0.03),
      'قبل',
      size.width,
      bg: s.brand.dark,
      fg: const Color(0xFFFFFFFF),
      align: align,
    );
    paintLabel(
      canvas,
      Rect.fromLTRB(
        afterCell.left,
        afterCell.top,
        afterCell.right,
        afterCell.bottom - lift,
      ).deflate(s.frame == null ? 0 : size.width * 0.03),
      'بعد',
      size.width,
      bg: s.brand.primary,
      fg: const Color(0xFFFFFFFF),
      align: align,
    );
  }
  paintOverlay(canvas, size, s.overlay);
  if (s.frame != null) paintBrandFrame(canvas, size, s.frame!);
  return recorder.endRecording().toImage(
    (size.width * scale).round(),
    (size.height * scale).round(),
  );
}

/// إطار واحد كامل الشاشة (للفيديو). القالب والإطار يترسمون بطبقة منفصلة.
Future<ui.Image> renderSingle({
  required ui.Image image,
  required Photo photo,
  required Size size,
  required Framing framing,
  required Brand brand,
  bool after = false,
  bool label = true,
  bool framed = false,
  ui.Image? overlay,
  BrandFrame? frame,
  double scale = 1,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  final cell = Offset.zero & size;
  paintPhoto(canvas, cell, image, photo, framing);
  if (label) {
    paintLabel(
      canvas,
      framed || frame != null
          ? Rect.fromLTWH(0, 0, size.width, size.height * 0.86)
          : cell.deflate(size.width * 0.02),
      after ? 'بعد' : 'قبل',
      size.width,
      bg: after ? brand.primary : brand.dark,
      fg: const Color(0xFFFFFFFF),
      align: framed || frame != null
          ? Alignment.bottomCenter
          : Alignment.topCenter,
    );
  }
  paintOverlay(canvas, size, overlay);
  if (frame != null) paintBrandFrame(canvas, size, frame);
  return recorder.endRecording().toImage(
    (size.width * scale).round(),
    (size.height * scale).round(),
  );
}

/// الطبقة الثابتة فوق الفيديو (القالب وإطار الهوية) بمقاس الفيديو، شفافة.
Future<ui.Image> renderOverlayLayer(
  Size size, {
  ui.Image? overlay,
  BrandFrame? frame,
  List<DesignElement> elements = const [],
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintOverlay(canvas, size, overlay);
  if (frame != null) paintBrandFrame(canvas, size, frame);
  paintElements(canvas, size, elements);
  return recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
}

Future<String> writePng(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return path;
}

/// تُستخدم من التقرير: صورة قبل وبعد مربعة بدون إطار.
Future<ui.Image?> renderReportComposite(CaseRecord c, Brand brand) async {
  if (c.before == null || c.after == null) return null;
  final ui.Image before, after;
  try {
    before = await loadImage(c.before!.path);
    after = await loadImage(c.after!.path);
  } on PhotoMissing {
    return null; // التقرير يطلع بدون صورة قبل وبعد.
  }
  final format = PostFormat.square;
  final (cell, _) = cellsFor(format.size, Layout.sideBySide);
  final offsetY = brand.alignTarget == AlignTarget.eyes ? 0.08 : 0.0;
  var z = 1.0;
  for (final (img, photo) in [(before, c.before!), (after, c.after!)]) {
    z = math.max(
      z,
      coverZoom(
        cell,
        Size(img.width.toDouble(), img.height.toDouble()),
        photo,
        Framing(offsetY: offsetY),
      ),
    );
  }
  return renderComposite(
    CompositeSpec(
      before: before,
      after: after,
      beforePhoto: c.before!,
      afterPhoto: c.after!,
      brand: brand,
      format: format,
      framing: Framing(zoom: z.clamp(0.4, 6.0), offsetY: offsetY),
    ),
    scale: 0.7,
  );
}
