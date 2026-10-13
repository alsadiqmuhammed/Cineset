import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/design.dart';
import 'package:rival_clinic/main_studio.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/render.dart' show PostFormat;
import 'package:rival_clinic/screens/compose_screen.dart';
import 'package:rival_clinic/store.dart';

import 'flow_test.dart' show fakeSmile, fresh, phone, settle;

void main() {
  test('every section has about thirty templates in both sizes', () {
    for (final s in Section.values) {
      final all = templatesFor(s);
      expect(all.length, greaterThanOrEqualTo(30));
      expect(all.map((t) => t.id).toSet().length, all.length);
      for (final f in [PostFormat.portrait, PostFormat.story]) {
        for (final n in [1, 2]) {
          expect(
            all.where((t) => t.format == f && t.photos == n).length,
            greaterThanOrEqualTo(7),
          );
        }
      }
    }
  });

  testWidgets('studio opens on the dental section and switches to beauty', (
    tester,
  ) async {
    phone(tester);
    await fresh(tester);
    await tester.runAsync(() => Store.instance.open(Section.dental));
    await tester.pumpWidget(const StudioApp());
    await settle(tester, 3);
    expect(find.text('ريڤال ستوديو'), findsOneWidget);
    expect(find.text('صورة قبل'), findsOneWidget);
    expect(find.text('صورة بعد'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('ريڤال بيوتي'));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester, 4);
    expect(Store.instance.section, Section.beauty);
    expect(find.text('قوالب ريڤال بيوتي'), findsOneWidget);
  });

  testWidgets('one photo designs with single-photo templates only', (
    tester,
  ) async {
    phone(tester);
    final dir = await fresh(tester);
    await tester.runAsync(() => Store.instance.open(Section.dental));
    final path = (await tester.runAsync(
      () => fakeSmile('${dir.path}/a.png', after: true),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: dental.theme(),
        home: ComposeScreen.photos(after: Photo(path)),
      ),
    );
    await settle(tester, 12);
    final singles = templatesFor(
      Section.dental,
    ).where((t) => t.photos == 1).length;
    expect(find.text('القالب · ${ar(singles)}'), findsOneWidget);
    expect(find.text('بدون قالب'), findsNothing);
    expect(find.text('صورتين'), findsNothing);
  });

  testWidgets('two photos can filter stories', (tester) async {
    phone(tester);
    final dir = await fresh(tester);
    await tester.runAsync(() => Store.instance.open(Section.beauty));
    final a = (await tester.runAsync(
      () => fakeSmile('${dir.path}/a.png', after: false),
    ))!;
    final b = (await tester.runAsync(
      () => fakeSmile('${dir.path}/b.png', after: true),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: beauty.theme(),
        home: ComposeScreen.photos(before: Photo(a), after: Photo(b)),
      ),
    );
    await settle(tester, 12);
    final all = templatesFor(Section.beauty);
    expect(find.text('القالب · ${ar(all.length)}'), findsOneWidget);
    await tester.tap(find.text('ستوري'));
    await tester.pump();
    final stories = all.where((t) => t.format == PostFormat.story).length;
    expect(find.text('القالب · ${ar(stories)}'), findsOneWidget);
  });
}
