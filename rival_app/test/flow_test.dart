import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/main.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/render.dart';
import 'package:rival_clinic/screens/compose_screen.dart';
import 'package:rival_clinic/store.dart';

/// صورة تجريبية: فم بنقطتين معروفتين.
Future<String> fakeSmile(String path, {required bool after}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const size = Size(900, 1200);
  c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFD9A98B));
  c.drawOval(
    Rect.fromCenter(center: const Offset(450, 700), width: 400, height: 160),
    Paint()..color = const Color(0xFF7A2E2E),
  );
  for (var i = 0; i < 6; i++) {
    c.drawRect(
      Rect.fromLTWH(320 + i * 45.0, 650, 40, after ? 60 : 50 + (i % 3) * 8),
      Paint()..color = after ? Colors.white : const Color(0xFFE3D3A4),
    );
  }
  final img = await rec.endRecording().toImage(900, 1200);
  return writePng(img, path);
}

/// يخلّي عمليات الملفات الحقيقية تكمل، ويرسم بين كل مرة.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('add patient, open a case and design a before/after post', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('rival'),
    );
    await tester.runAsync(() => Store.instance.load(dir: dir));

    await tester.pumpWidget(const RivalApp());
    expect(find.text('ماكو مراجعين بعد'), findsOneWidget);

    await tester.tap(find.text('مراجع جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(0),
      'زينب علي',
    );
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(1),
      '07701234567',
    );
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(find.text('زينب علي'), findsWidgets);

    await tester.tap(find.text('حالة جديدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فينير'));
    await tester.tap(find.text('إنشاء'));
    await settle(tester);
    expect(find.text('تصميم صورة قبل وبعد'), findsOneWidget);

    // الصور تنضاف هنا مباشرة لأن الكاميرا ما تشتغل بالاختبار.
    final record = Store.instance.patients.single.cases.single;
    await tester.runAsync(() async {
      final b = await fakeSmile('${dir!.path}/b.png', after: false);
      final a = await fakeSmile('${dir.path}/a.png', after: true);
      record.before = Photo(
        b,
        a: const Offset(250, 700),
        b: const Offset(650, 700),
      );
      record.after = Photo(
        a,
        a: const Offset(250, 700),
        b: const Offset(650, 700),
      );
      await loadImage(b);
      await loadImage(a);
    });
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فينير'));
    await tester.pumpAndSettle();
    expect(find.text('محاذاة جاهزة'), findsNWidgets(2));

    await tester.tap(find.text('تصميم صورة قبل وبعد'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final preview = tester.widget<RawImage>(
      find.descendant(
        of: find.byType(ComposeScreen),
        matching: find.byType(RawImage),
      ),
    );
    expect(preview.image, isNotNull);

    final out = await tester.runAsync(() async {
      final img = await renderComposite(
        CompositeSpec(
          before: await loadImage(record.before!.path),
          after: await loadImage(record.after!.path),
          beforePhoto: record.before!,
          afterPhoto: record.after!,
        ),
      );
      return (img.width, img.height);
    });
    expect(out, (1080, 1350));
  });
}
