import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/design.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/render.dart';
import 'package:rival_clinic/screens/design_canvas.dart';

Future<ui.Image> solid(Color c, {Color? right}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 400), Paint()..color = c);
  if (right != null) {
    canvas.drawRect(
      const Rect.fromLTWH(200, 0, 200, 400),
      Paint()..color = right,
    );
  }
  return rec.endRecording().toImage(400, 400);
}

Future<ByteData> pixels(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;

Color at(ByteData d, int w, Offset p) {
  final i = (p.dy.round() * w + p.dx.round()) * 4;
  return Color.fromARGB(
    d.getUint8(i + 3),
    d.getUint8(i),
    d.getUint8(i + 1),
    d.getUint8(i + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'template windows match the transparent areas of every template',
    () async {
      for (final t in [...dentalTemplates, ...beautyTemplates]) {
        final data = await rootBundle.load(t.asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final img = (await codec.getNextFrame()).image;
        expect(
          Size(img.width.toDouble(), img.height.toDouble()),
          t.format.size,
          reason: t.id,
        );
        final px = await pixels(img);
        for (final r in t.slots) {
          expect(
            at(px, img.width, r.center).a,
            lessThan(0.05),
            reason: '${t.id} window',
          );
          // خارج الشباك بشوي: القالب نفسه (مو شفاف).
          expect(
            at(px, img.width, Offset(r.center.dx, r.bottom + 12)).a,
            greaterThan(0.9),
            reason: '${t.id} below window',
          );
        }
        // "قبل" (أول شباك) باليمين.
        if (t.slots.length == 2) {
          expect(t.slots[0].center.dx, greaterThan(t.slots[1].center.dx));
        }
      }
    },
  );

  group('marks', () {
    late DesignSpec base;
    const red = Color(0xFFFF0000),
        green = Color(0xFF00FF00),
        blue = Color(0xFF0000FF);

    setUp(() async {
      final photo = await solid(green, right: blue);
      base = DesignSpec(
        brand: dental,
        size: const Size(400, 400),
        slots: const [Rect.fromLTWH(0, 0, 400, 400)],
        fills: [SlotFill(Which.before)],
        photos: {Which.before: (photo, const Photo('x'))},
        labels: false,
      );
    });

    Future<Color> render(List<Mark> marks, Offset p) async {
      final img = await renderDesign(base.copyWith(marks: marks));
      return at(await pixels(img), 400, p);
    }

    test('pen draws, eraser removes the drawing but keeps the photo', () async {
      final pen = Mark(
        MarkKind.pen,
        [const Offset(20, 100), const Offset(180, 100)],
        red,
        0.03,
      );
      expect(await render([pen], const Offset(100, 100)), red);
      final eraser = Mark(
        MarkKind.eraser,
        [const Offset(20, 100), const Offset(180, 100)],
        red,
        0.03,
      );
      expect(await render([pen, eraser], const Offset(100, 100)), green);
      // رسم بعد الممحاة يبقى.
      final pen2 = Mark(
        MarkKind.pen,
        [const Offset(20, 100), const Offset(180, 100)],
        blue,
        0.03,
      );
      expect(await render([pen, eraser, pen2], const Offset(100, 100)), blue);
    });

    test(
      'blur softens the photo only inside its area, and the eraser undoes it',
      () async {
        final blur = Mark(
          MarkKind.blurRect,
          [const Offset(150, 150), const Offset(250, 250)],
          red,
          0.01,
        );
        final inside = await render([blur], const Offset(200, 200));
        expect(
          inside.g,
          greaterThan(0.1),
        ); // اختلط الأخضر ويه الأزرق عند الحافة
        expect(inside.b, greaterThan(0.1));
        expect(
          await render([blur], const Offset(198, 50)),
          green,
        ); // برّه المنطقة حاد
        final eraser = Mark(
          MarkKind.eraser,
          [const Offset(150, 200), const Offset(250, 200)],
          red,
          0.05,
        );
        expect(await render([blur, eraser], const Offset(198, 200)), green);
      },
    );

    test('shapes: arrow, circle and rectangle', () async {
      final arrow = Mark(
        MarkKind.arrow,
        [const Offset(50, 300), const Offset(350, 300)],
        red,
        0.02,
      );
      expect(await render([arrow], const Offset(200, 300)), red);
      final circle = Mark(
        MarkKind.circle,
        [const Offset(100, 100), const Offset(300, 300)],
        red,
        0.02,
      );
      expect(await render([circle], const Offset(100, 200)), red);
      expect(
        await render([circle], const Offset(200, 200)),
        isNot(red),
      ); // بس الحافة
      final rect = Mark(
        MarkKind.rect,
        [const Offset(100, 100), const Offset(300, 300)],
        red,
        0.02,
      );
      expect(await render([rect], const Offset(200, 100)), red);
    });

    test('the template stays on top of every addition', () async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(
        const Rect.fromLTWH(0, 0, 400, 50),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final template = await rec.endRecording().toImage(400, 400);
      final pen = Mark(
        MarkKind.pen,
        [const Offset(20, 25), const Offset(380, 25)],
        red,
        0.03,
      );
      final img = await renderDesign(
        DesignSpec(
          brand: dental,
          size: base.size,
          slots: base.slots,
          fills: base.fills,
          photos: base.photos,
          template: template,
          labels: false,
          marks: [pen],
        ),
      );
      final px = await pixels(img);
      expect(at(px, 400, const Offset(100, 25)), const Color(0xFFFFFFFF));
    });
  });

  testWidgets('dragging moves the photos together, or one by one', (
    tester,
  ) async {
    final c = DesignController()
      ..fills = [SlotFill(Which.before), SlotFill(Which.after)];
    late DesignSpec spec;
    await tester.runAsync(() async {
      final photo = await solid(const Color(0xFF00FF00));
      spec = DesignSpec(
        brand: dental,
        size: const Size(800, 400),
        slots: const [
          Rect.fromLTWH(400, 0, 400, 400),
          Rect.fromLTWH(0, 0, 400, 400),
        ],
        fills: c.fills,
        photos: {
          Which.before: (photo, const Photo('b')),
          Which.after: (photo, const Photo('a')),
        },
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: dental.theme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: DesignCanvas(controller: c, spec: () => spec),
            ),
          ),
        ),
      ),
    );
    final canvas = find.byType(DesignCanvas);
    // نص التصميم = ٢ بكسل تصميم لكل بكسل شاشة. سحب ٥٠ = ١٠٠ بالتصميم = ربع الشباك.
    await tester.timedDrag(
      canvas,
      const Offset(50, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    for (final f in c.fills) {
      expect(f.framing.offsetX, closeTo(0.25, 0.05));
    }
    c.setLinked(false);
    final rightHalf = tester.getCenter(canvas) + const Offset(80, 0);
    await tester.timedDragFrom(
      rightHalf,
      const Offset(0, 40),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(
      c.fills[0].framing.offsetY,
      closeTo(0.2, 0.05),
    ); // شباك "قبل" باليمين
    expect(c.fills[1].framing.offsetY, 0);

    // أداة رسم: السحب يضيف خط، والتراجع يشيله.
    c.setTool(MarkKind.pen);
    await tester.timedDrag(
      canvas,
      const Offset(60, 20),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(c.marks.single.kind, MarkKind.pen);
    expect(c.marks.single.points.length, greaterThan(3));
    c.undo();
    expect(c.marks, isEmpty);
    c.redo();
    expect(c.marks, hasLength(1));
  });

  test('fit fills each window without black bars', () async {
    final img = await solid(const Color(0xFF00FF00));
    for (final t in [...dentalTemplates, ...beautyTemplates]) {
      for (final cell in t.slots) {
        const p = Photo('x', a: Offset(150, 220), b: Offset(250, 225));
        final f = fitFraming(cell, img, p, const Framing(offsetY: -0.1));
        final z = coverZoom(cell, const Size(400, 400), p, f);
        expect(f.zoom, greaterThanOrEqualTo(z - 1e-9), reason: t.id);
      }
    }
  });
}
