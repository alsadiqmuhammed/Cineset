import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../design.dart';
import '../models.dart';
import '../render.dart';

/// وضع العرض للمراجع: الشاشة كلها صورة وحدة، وخط تسحبه بإصبعك يكشف
/// القبل والبعد (مثل برامج العيادات الكبيرة). يبدي بحركة توضيحية.
class PresentScreen extends StatefulWidget {
  final Map<Which, (ui.Image, Photo)> photos;
  final Map<Which, PhotoAdjust> adjust;
  final Brand brand;
  const PresentScreen({
    super.key,
    required this.photos,
    required this.brand,
    this.adjust = const {},
  });

  @override
  State<PresentScreen> createState() => _PresentScreenState();
}

class _PresentScreenState extends State<PresentScreen>
    with SingleTickerProviderStateMixin {
  double _x = 0.5;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _intro.addListener(() {
      // الخط يمسح يمين ويسار ويستقر بالنص.
      final t = Curves.easeInOut.transform(_intro.value);
      setState(() => _x = 0.5 + 0.32 * math.sin(t * math.pi * 2));
    });
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          final cell = Offset.zero & size;
          Framing fit(Which w) {
            final p = widget.photos[w]!;
            return fitFraming(cell, p.$1, p.$2, const Framing());
          }

          final two = widget.photos.length == 2;
          final fills = two
              ? [
                  SlotFill(Which.before, fit(Which.before)),
                  SlotFill(Which.after, fit(Which.after)),
                ]
              : [
                  SlotFill(
                    widget.photos.keys.first,
                    fit(widget.photos.keys.first),
                  ),
                ];
          if (two) {
            final z = math.max(fills[0].framing.zoom, fills[1].framing.zoom);
            for (final f in fills) {
              f.framing = f.framing.copyWith(zoom: z);
            }
          }
          final spec = DesignSpec(
            brand: widget.brand,
            size: size,
            slots: [for (final _ in fills) cell],
            fills: fills,
            photos: widget.photos,
            labels: false,
            background: Colors.black,
            adjust: widget.adjust,
            masks: two
                ? [
                    null,
                    SlotMask(
                      fadeFrom: Alignment.centerRight,
                      fadeTo: Alignment.centerLeft,
                      fadeStart: (1 - _x) - 0.002,
                      fadeEnd: (1 - _x) + 0.002,
                    ),
                  ]
                : null,
            seam: two ? Colors.white : null,
          );
          return GestureDetector(
            onHorizontalDragStart: (_) => _intro.stop(),
            onHorizontalDragUpdate: (d) => setState(
              () => _x = (d.localPosition.dx / size.width).clamp(0.0, 1.0),
            ),
            onTapUp: (d) {
              _intro.stop();
              setState(() => _x = d.localPosition.dx / size.width);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _Painter(spec)),
                if (two) ...[
                  Positioned(
                    left: _x * size.width - 24,
                    top: size.height / 2 - 24,
                    child: IgnorePointer(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x66000000), blurRadius: 14),
                          ],
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  _tag('قبل', Alignment.topRight, Colors.black54),
                  _tag('بعد', Alignment.topLeft, widget.brand.primary),
                ],
                SafeArea(
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String text, Alignment a, Color bg) => SafeArea(
    child: Align(
      alignment: a,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _Painter extends CustomPainter {
  final DesignSpec spec;
  _Painter(this.spec);
  @override
  void paint(Canvas canvas, Size size) => paintDesign(canvas, spec);
  @override
  bool shouldRepaint(_Painter o) => true;
}
