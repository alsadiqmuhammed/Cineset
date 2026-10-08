import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'models.dart';
import 'theme.dart';

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
class Framing {
  final double zoom, offsetY;
  const Framing({this.zoom = 1, this.offsetY = 0});
}

final _cache = <String, ui.Image>{};

Future<ui.Image> loadImage(String path) async {
  final cached = _cache[path];
  if (cached != null) return cached;
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final image = (await codec.getNextFrame()).image;
  _cache[path] = image;
  return image;
}

void evictImage(String path) => _cache.remove(path)?.dispose();

/// تحويل من بكسلات الصورة لمكانها داخل الخلية: نقطتا المحاذاة تقعان بنفس
/// المكان بكل الخلايا (منتصفهما بالوسط، والخط بينهما أفقي وبنفس الطول).
/// بدون نقاط: الصورة تملأ الخلية من الوسط.
class CellMapping {
  final Offset target, mid;
  final double scale, angle;
  const CellMapping(this.target, this.mid, this.scale, this.angle);

  factory CellMapping.of(Rect cell, Size image, Photo p, Framing f) {
    final target = Offset(
      cell.center.dx,
      cell.top + cell.height * (0.5 + f.offsetY),
    );
    if (!p.aligned) {
      return CellMapping(
        target,
        Offset(image.width / 2, image.height / 2),
        math.max(cell.width / image.width, cell.height / image.height) * f.zoom,
        0,
      );
    }
    final left = p.a!.dx <= p.b!.dx ? p.a! : p.b!;
    final right = left == p.a ? p.b! : p.a!;
    final d = right - left;
    return CellMapping(
      target,
      (left + right) / 2,
      cell.width * 0.42 * f.zoom / math.max(d.distance, 1.0),
      -math.atan2(d.dy, d.dx),
    );
  }

  Offset map(Offset p) {
    final v = (p - mid) * scale;
    final c = math.cos(angle), s = math.sin(angle);
    return target + Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }
}

/// أقل تقريب يخلّي الصورة تغطي الخلية كلها بدون حواف سودة.
double coverZoom(Rect cell, Size image, Photo p, double offsetY) {
  final m = CellMapping.of(cell, image, p, Framing(offsetY: offsetY));
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

void paintLabel(Canvas canvas, Rect cell, String text, double unit) {
  final style = ui.ParagraphStyle(
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
    fontSize: unit * 0.042,
    fontWeight: FontWeight.w600,
  );
  final builder = ui.ParagraphBuilder(style)
    ..pushStyle(ui.TextStyle(color: const Color(0xFF1A1408)))
    ..addText(text);
  final para = builder.build()
    ..layout(ui.ParagraphConstraints(width: cell.width));
  final w = para.longestLine + unit * 0.06;
  final h = para.height + unit * 0.018;
  final pill = Rect.fromCenter(
    center: Offset(cell.center.dx, cell.top + unit * 0.05 + h / 2),
    width: w,
    height: h,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(pill, Radius.circular(h / 2)),
    Paint()..color = kGold,
  );
  canvas.drawParagraph(
    para,
    Offset(cell.left, pill.top + (h - para.height) / 2),
  );
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

class CompositeSpec {
  final ui.Image before, after;
  final Photo beforePhoto, afterPhoto;
  final PostFormat format;
  final Layout layout;
  final Framing framing;
  final ui.Image? overlay;
  final bool labels;

  const CompositeSpec({
    required this.before,
    required this.after,
    required this.beforePhoto,
    required this.afterPhoto,
    this.format = PostFormat.portrait,
    this.layout = Layout.sideBySide,
    this.framing = const Framing(),
    this.overlay,
    this.labels = true,
  });
}

/// صورة "قبل وبعد" بخليتين. نفس الدالة للمعاينة (scale صغير) وللتصدير (scale = 1).
Future<ui.Image> renderComposite(CompositeSpec s, {double scale = 1}) {
  final size = s.format.size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  final gap = size.width * 0.006;
  final (Rect first, Rect second) = s.layout == Layout.sideBySide
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
  canvas.drawRect(Offset.zero & size, Paint()..color = kGold);
  // بالعربي "قبل" تكون باليمين (أو بالأعلى).
  final beforeCell = s.layout == Layout.sideBySide ? second : first;
  final afterCell = s.layout == Layout.sideBySide ? first : second;
  paintPhoto(canvas, beforeCell, s.before, s.beforePhoto, s.framing);
  paintPhoto(canvas, afterCell, s.after, s.afterPhoto, s.framing);
  if (s.labels) {
    paintLabel(canvas, beforeCell, 'قبل', size.width);
    paintLabel(canvas, afterCell, 'بعد', size.width);
  }
  paintOverlay(canvas, size, s.overlay);
  return recorder.endRecording().toImage(
    (size.width * scale).round(),
    (size.height * scale).round(),
  );
}

/// إطار واحد كامل الشاشة (للفيديو).
Future<ui.Image> renderSingle({
  required ui.Image image,
  required Photo photo,
  required Size size,
  required Framing framing,
  ui.Image? overlay,
  String? label,
  double scale = 1,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  final cell = Offset.zero & size;
  paintPhoto(canvas, cell, image, photo, framing);
  if (label != null) {
    paintLabel(canvas, cell.deflate(size.width * 0.02), label, size.width);
  }
  paintOverlay(canvas, size, overlay);
  return recorder.endRecording().toImage(
    (size.width * scale).round(),
    (size.height * scale).round(),
  );
}

/// القالب لوحده بمقاس الفيديو (شفاف)، حتى يبقى ثابت فوق الإطارات.
Future<ui.Image> renderOverlayLayer(Size size, ui.Image overlay) {
  final recorder = ui.PictureRecorder();
  paintOverlay(Canvas(recorder), size, overlay);
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
