import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/main.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/render.dart';
import 'package:rival_clinic/report_pdf.dart';
import 'package:rival_clinic/design.dart';
import 'package:rival_clinic/screens/design_canvas.dart';
import 'package:rival_clinic/stats.dart';
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
Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<Directory> fresh(WidgetTester tester) async {
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('rival'),
  ))!;
  await tester.runAsync(() => Store.instance.init(dir: dir));
  clearImageCache();
  return dir;
}

void main() {
  testWidgets('doctor picks the beauty section on start', (tester) async {
    phone(tester);
    await fresh(tester);
    await tester.pumpWidget(const RivalApp());
    expect(find.text('اختار القسم'), findsOneWidget);
    // الاختيار يقرأ ويكتب ملفات حقيقية، فنخلّيه يشتغل بالوقت الحقيقي.
    await tester.runAsync(() async {
      await tester.tap(find.text('قسم التجميل'));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('المراجعات'), findsWidgets); // بصيغة المؤنث
    expect(find.text('مراجعة جديدة'), findsOneWidget);
    expect(Store.instance.section, Section.beauty);
  });

  testWidgets('dental: add patient, case, teeth, visit and design', (
    tester,
  ) async {
    phone(tester);
    final dir = await fresh(tester);
    await tester.runAsync(() => Store.instance.open(Section.dental));
    await tester.pumpWidget(const RivalApp(initial: Section.dental));
    await settle(tester);

    await tester.tap(find.text('مراجع جديد').first);
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'زينب علي');
    await tester.enterText(fields.at(1), '07701234567');
    await tester.enterText(fields.at(2), '28');
    await tester.tap(find.text('أنثى'));
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(find.text('زينب علي'), findsWidgets);
    expect(find.text('٢٨ سنة'), findsOneWidget);

    await tester.tap(find.text('حالة جديدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فينير'));
    await tester.tap(find.text('د. مصطفى عبد الكريم'));
    await tester.tap(find.text('إنشاء'));
    await settle(tester);
    expect(find.text('تصميم قبل وبعد'), findsOneWidget);

    final record = Store.instance.patients.single.cases.single;
    expect(record.doctorId, 'd1');

    await tester.scrollUntilVisible(find.text('11'), 300);
    await tester.tap(find.text('11'));
    await tester.tap(find.text('21'));
    await settle(tester, 3);
    expect(record.teeth, [11, 21]);

    // الصور تنضاف هنا مباشرة لأن الكاميرا ما تشتغل بالاختبار.
    await tester.runAsync(() async {
      final b = await fakeSmile('${dir.path}/b.png', after: false);
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
      await loadAssetImage(dental.logoReversed);
    });
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text('فينير'));
    await settle(tester);
    expect(find.text('محاذاة جاهزة'), findsNWidgets(2));

    await tester.runAsync(() async {
      for (final t in templatesFor(Section.dental)) {
        await loadAssetImage(t.asset);
      }
    });
    await tester.tap(find.text('تصميم قبل وبعد'));
    await settle(tester);
    // المعاينة الحيّة جاهزة بقالب البوست (صورتين).
    expect(find.byType(DesignCanvas), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('بوست · صورتين'), findsOneWidget);

    // نجرب نختار قالب صورة وحدة، ونضبب.
    await tester.tap(find.text('بوست · صورة'));
    await settle(tester);
    expect(find.text('صورة بعد'), findsOneWidget);
    await tester.drag(
      find.byIcon(Icons.open_with),
      const Offset(300, 0),
    ); // شريط الأدوات يتمرر
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.blur_on));
    await tester.pump();
    await tester.timedDrag(
      find.byType(DesignCanvas),
      const Offset(60, 60),
      const Duration(milliseconds: 300),
    );
    await settle(tester, 3);
    expect(find.byTooltip('تراجع'), findsOneWidget);
    final undo = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.undo),
        matching: find.byType(IconButton),
      ),
    );
    expect(undo.onPressed, isNotNull);
  });

  testWidgets('all four PDF reports are generated', (tester) async {
    final dir = await fresh(tester);
    await tester.runAsync(() async {
      final store = Store.instance;
      await store.open(Section.dental);
      final p = await store.addPatient(
        'زينب علي',
        '07701234567',
        birthYear: 1998,
      );
      final b = await fakeSmile('${dir.path}/b.png', after: false);
      final a = await fakeSmile('${dir.path}/a.png', after: true);
      final c = CaseRecord(
        id: '1',
        title: 'فينير',
        created: DateTime.now().millisecondsSinceEpoch,
        doctorId: 'd1',
        teeth: [11, 12, 21, 22],
        note: 'ثمان قطع فينير، اللون BL2.',
        visits: [
          Visit(
            id: 'v',
            date: DateTime.now().millisecondsSinceEpoch,
            note: 'تحضير وطبعة',
          ),
        ],
        before: Photo(b, a: const Offset(250, 700), b: const Offset(650, 700)),
        after: Photo(a, a: const Offset(250, 700), b: const Offset(650, 700)),
      );
      p.cases.add(c);
      final files = [
        await caseReport(dental, p, c),
        await patientReport(dental, p),
        await doctorReport(
          dental,
          store.doctors.first,
          Stats.of(store, doctorId: 'd1'),
        ),
        await clinicReport(dental, Stats.of(store), period: Period.all),
      ];
      for (final f in files) {
        final bytes = f.readAsBytesSync();
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(20000));
      }
      final keep = Platform.environment['RIVAL_PDF_OUT'];
      if (keep != null) {
        for (final f in files) {
          f.copySync('$keep/${f.uri.pathSegments.last}');
        }
      }
    });
  });
}
