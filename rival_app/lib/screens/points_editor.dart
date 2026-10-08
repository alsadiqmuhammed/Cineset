import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../render.dart';
import '../brand.dart';

/// تحديد نقطتي المحاذاة يدوياً: اسحب النقطتين لزاويتي الفم (أو طرفي الأنياب)،
/// ونفس النقطتين بصورة "بعد" حتى تتطابق الصورتان.
class PointsEditor extends StatefulWidget {
  final Photo photo;
  const PointsEditor({super.key, required this.photo});

  @override
  State<PointsEditor> createState() => _PointsEditorState();
}

class _PointsEditorState extends State<PointsEditor> {
  ui.Image? _image;
  late Offset _a, _b; // بإحداثيات بكسلات الصورة
  int? _dragging;
  Offset? _finger;

  @override
  void initState() {
    super.initState();
    loadImage(widget.photo.path).then((img) {
      if (!mounted) return;
      setState(() {
        _image = img;
        _a = widget.photo.a ?? Offset(img.width * 0.35, img.height * 0.55);
        _b = widget.photo.b ?? Offset(img.width * 0.65, img.height * 0.55);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقاط المحاذاة'),
        actions: [
          TextButton(
            onPressed: img == null
                ? null
                : () => Navigator.pop(context, widget.photo.withPoints(_a, _b)),
            child: const Text('حفظ'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              context.brand.alignTarget == AlignTarget.mouth
                  ? 'اسحب النقطتين لزاويتي الفم (أو طرفي الأنياب). استخدم نفس المكان بصورتي قبل وبعد.'
                  : 'اسحبي النقطتين لمنتصف العينين (أو زاويتي الشفايف لجلسات الشفايف). نفس المكان بصورتي قبل وبعد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.brand.muted),
            ),
          ),
          Expanded(
            child: img == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(builder: (context, box) => _editor(img, box)),
          ),
        ],
      ),
    );
  }

  Widget _editor(ui.Image img, BoxConstraints box) {
    final fit = applyBoxFit(
      BoxFit.contain,
      Size(img.width.toDouble(), img.height.toDouble()),
      box.biggest,
    );
    final scale = fit.destination.width / img.width;
    final origin = Offset(
      (box.maxWidth - fit.destination.width) / 2,
      (box.maxHeight - fit.destination.height) / 2,
    );
    Offset toScreen(Offset p) => origin + p * scale;
    Offset toImage(Offset s) {
      final p = (s - origin) / scale;
      return Offset(
        p.dx.clamp(0, img.width.toDouble()),
        p.dy.clamp(0, img.height.toDouble()),
      );
    }

    void move(Offset local) => setState(() {
      _finger = local;
      if (_dragging == 0) {
        _a = toImage(local);
      } else {
        _b = toImage(local);
      }
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        final da = (toScreen(_a) - d.localPosition).distance;
        final db = (toScreen(_b) - d.localPosition).distance;
        _dragging = da <= db ? 0 : 1;
        move(d.localPosition);
      },
      onPanUpdate: (d) => move(d.localPosition),
      onPanEnd: (_) => setState(() => _finger = null),
      onTapUp: (d) {
        final da = (toScreen(_a) - d.localPosition).distance;
        final db = (toScreen(_b) - d.localPosition).distance;
        _dragging = da <= db ? 0 : 1;
        move(d.localPosition);
        setState(() => _finger = null);
      },
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: origin & fit.destination,
            child: Image.file(File(widget.photo.path), fit: BoxFit.fill),
          ),
          CustomPaint(
            size: box.biggest,
            painter: _PointsPainter(
              toScreen(_a),
              toScreen(_b),
              context.brand.accent,
            ),
          ),
          if (_finger != null)
            Positioned(
              left: _finger!.dx - 60,
              top: _finger!.dy - 170,
              child: RawMagnifier(
                size: const Size(120, 120),
                magnificationScale: 2.5,
                focalPointOffset: const Offset(0, 110),
                decoration: MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: context.brand.primary, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PointsPainter extends CustomPainter {
  final Offset a, b;
  final Color color;
  _PointsPainter(this.a, this.b, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(a, b, line);
    for (final p in [a, b]) {
      canvas.drawCircle(p, 14, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(
        p,
        14,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_PointsPainter old) => old.a != a || old.b != b;
}
