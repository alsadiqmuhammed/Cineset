import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/design.dart';
import 'package:rival_clinic/models.dart';

import 'design_test.dart' show solid, pixels, at;

void main() {
  const red = Color(0xFFFF0000), blue = Color(0xFF0000FF);
  const size = Size(400, 400);
  const full = Rect.fromLTWH(0, 0, 400, 400);

  Future<ByteData> draw({
    List<Rect> slots = const [full, full],
    List<SlotMask?>? masks,
    Map<Which, PhotoAdjust> adjust = const {},
    bool backdrop = false,
    Color? background,
  }) async {
    final before = await solid(red), after = await solid(blue);
    final spec = DesignSpec(
      brand: dental,
      size: size,
      slots: slots,
      fills: [
        for (var i = 0; i < slots.length; i++)
          SlotFill(i == 0 ? Which.before : Which.after),
      ],
      photos: {
        Which.before: (before, const Photo('b')),
        Which.after: (after, const Photo('a')),
      },
      labels: false,
      masks: masks,
      adjust: adjust,
      backdrop: backdrop,
      background: background,
    );
    final img = await renderDesign(spec);
    return pixels(img);
  }

  test('blend: before on the right melts into after on the left', () async {
    final px = await draw(
      masks: const [
        null,
        SlotMask(
          fadeFrom: Alignment(1, 0),
          fadeTo: Alignment(-1, 0),
          fadeStart: 0.4,
          fadeEnd: 0.6,
        ),
      ],
    );
    expect(at(px, 400, const Offset(20, 200)), blue);
    expect(at(px, 400, const Offset(380, 200)), red);
    // بالنص الثنتين مخلوطات: لا حد حاد.
    final mid = at(px, 400, const Offset(200, 200));
    expect((mid.r * 255).round(), inInclusiveRange(60, 200));
    expect((mid.b * 255).round(), inInclusiveRange(60, 200));
  });

  test('soft edge fades a single photo into the background', () async {
    const bg = Color(0xFFFFFFFF);
    final px = await draw(
      slots: const [full],
      masks: const [SlotMask(feather: 30)],
      background: bg,
    );
    expect(at(px, 400, const Offset(200, 200)), red);
    // على حد الشباك الصورة اختفت تقريباً (ماكو خط).
    expect(at(px, 400, const Offset(2, 200)).g, greaterThan(0.97));
  });

  test('a circle drawn over a big photo keeps its corners clear', () async {
    final px = await draw(
      slots: const [full, Rect.fromLTWH(200, 200, 200, 200)],
      masks: const [
        null,
        SlotMask(shape: SlotShape.oval),
      ],
    );
    expect(at(px, 400, const Offset(300, 300)), blue); // داخل الدائرة
    expect(at(px, 400, const Offset(205, 205)), red); // زاوية مربعها
  });

  test('tooth and drop shapes cut the photo', () async {
    for (final shape in [SlotShape.tooth, SlotShape.drop]) {
      final px = await draw(
        slots: const [full, Rect.fromLTWH(100, 100, 200, 200)],
        masks: [
          null,
          SlotMask(shape: shape),
        ],
      );
      expect(at(px, 400, const Offset(200, 220)), blue, reason: '$shape');
      expect(at(px, 400, const Offset(102, 298)), red, reason: '$shape');
    }
  });

  test('light and colour adjustments change only their photo', () async {
    final px = await draw(
      slots: const [
        Rect.fromLTWH(200, 0, 200, 400),
        Rect.fromLTWH(0, 0, 200, 400),
      ],
      adjust: const {Which.after: PhotoAdjust(brightness: 0.6)},
    );
    final a = at(px, 400, const Offset(100, 200));
    expect((a.r * 255).round(), greaterThan(20)); // الأزرق فتح
    expect(at(px, 400, const Offset(300, 200)), red);
    expect(PhotoAdjust.none.filter, isNull);
  });

  test('auto adjust brightens a dark photo and cools a yellow one', () {
    Uint8List fill(int r, int g, int b) => Uint8List.fromList([
      for (var i = 0; i < 64; i++) ...[r, g, b, 255],
    ]);
    expect(PhotoAdjust.fromPixels(fill(40, 35, 30)).brightness, greaterThan(0));
    expect(PhotoAdjust.fromPixels(fill(230, 200, 90)).warmth, lessThan(0));
  });

  test('moving the blend shifts where after starts', () async {
    const m = SlotMask(
      fadeFrom: Alignment(1, 0),
      fadeTo: Alignment(-1, 0),
      fadeStart: 0.45,
      fadeEnd: 0.55,
    );
    // الخط ينزاح لليمين (بداية التدرّج من اليمين): بعد تغطي أكثر.
    final px = await draw(masks: [null, m.moved(shift: -0.3)]);
    expect(at(px, 400, const Offset(300, 200)).b, greaterThan(0.95));
    // اتجاه أفقي: قبل فوق وبعد تحت.
    final h = await draw(
      masks: [
        null,
        m.moved(dir: FadeDir.horizontal),
      ],
    );
    expect(at(h, 400, const Offset(200, 20)), red);
    expect(at(h, 400, const Offset(200, 380)), blue);
    // عرض الذوبان ما يطلع برّه الحدود.
    final wide = m.moved(width: 5);
    expect(wide.fadeStart, greaterThanOrEqualTo(0));
    expect(wide.fadeEnd, lessThanOrEqualTo(1));
  });

  test('mono turns its photo grey and the seam draws a line', () async {
    final px = await draw(
      slots: const [full],
      masks: const [SlotMask(mono: true)],
    );
    final c = at(px, 400, const Offset(200, 200));
    expect(c.r, closeTo(c.g, 0.02));
    final before = await solid(red), after = await solid(blue);
    final spec = DesignSpec(
      brand: dental,
      size: size,
      slots: const [full, full],
      fills: [SlotFill(Which.before), SlotFill(Which.after)],
      photos: {
        Which.before: (before, const Photo('b')),
        Which.after: (after, const Photo('a')),
      },
      labels: false,
      masks: const [
        null,
        SlotMask(
          fadeFrom: Alignment(1, 0),
          fadeTo: Alignment(-1, 0),
          fadeStart: 0.49,
          fadeEnd: 0.51,
        ),
      ],
      seam: const Color(0xFFFFFFFF),
    );
    final line = await pixels(await renderDesign(spec));
    final mid = at(line, 400, const Offset(200, 200));
    expect(mid.g, greaterThan(0.5)); // أبيض على الخط
  });

  test('auto adjust follows different rules for teeth and skin', () {
    final px = Uint8List.fromList([
      for (var i = 0; i < 64; i++) ...[200, 160, 140, 255],
    ]);
    final dental = PhotoAdjust.fromPixels(px);
    final beauty = PhotoAdjust.fromPixels(px, beauty: true);
    // البشرة أدفأ وأنعم، والأسنان تباين أعلى ولون أبرد.
    expect(beauty.warmth, greaterThan(dental.warmth));
    expect(beauty.contrast, lessThan(dental.contrast));
    expect(beauty.fade, greaterThan(0));
    expect(dental.fade, 0);
  });

  test(
    'video layers: photos without the template, template on clear',
    () async {
      final before = await solid(red);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      // قالب: إطار أزرق وفتحة بالنص.
      c.drawRect(full, Paint()..color = blue);
      c.drawRect(
        const Rect.fromLTWH(100, 100, 200, 200),
        Paint()..blendMode = BlendMode.clear,
      );
      final tpl = await rec.endRecording().toImage(400, 400);
      final spec = DesignSpec(
        brand: dental,
        size: size,
        slots: const [Rect.fromLTWH(100, 100, 200, 200)],
        fills: [SlotFill(Which.after)],
        photos: {Which.after: (before, const Photo('a'))},
        template: tpl,
        labels: false,
      );
      final photos = await pixels(
        await renderDesign(spec, layer: DesignLayer.photos),
      );
      expect(at(photos, 400, const Offset(200, 200)), red);
      expect(at(photos, 400, const Offset(20, 20)), isNot(blue));
      final over = await pixels(
        await renderDesign(spec, layer: DesignLayer.overlay),
      );
      expect(at(over, 400, const Offset(20, 20)), blue);
      expect(at(over, 400, const Offset(200, 200)).a, 0);
    },
  );

  test('blurred backdrop fills the design behind the photos', () async {
    final px = await draw(
      slots: const [Rect.fromLTWH(150, 150, 100, 100)],
      masks: const [SlotMask(radius: 10)],
      backdrop: true,
    );
    // خارج الشباك: صورة "بعد" مضببة ومعتّمة (مو لون الخلفية).
    final c = at(px, 400, const Offset(20, 20));
    expect((c.b * 255).round(), greaterThan(120));
  });
}
