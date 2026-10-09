import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sections = [
    'أعمالي',
    'أدوات التصوير',
    'برتي ليدي',
    'دفتر الأفكار',
    'العدّة',
    'المختبر',
    'تطبيقاتي',
    'حياتي وعائلتي',
  ];

  testWidgets('every section opens on a phone-sized screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MeApp());
    for (final s in sections) {
      final card = find.text(s).last;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget, reason: s);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('notes are saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MeApp());
    await tester.ensureVisible(find.text('دفتر الأفكار'));
    await tester.tap(find.text('دفتر الأفكار'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'لقطة الغروب على شط العرب');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('لقطة الغروب على شط العرب'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notes'), contains('شط العرب'));
  });
}
