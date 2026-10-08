import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/render.dart';
import 'package:rival_clinic/screens/patient_screen.dart';
import 'package:rival_clinic/store.dart';

void main() {
  group('alignment', () {
    const cell = Rect.fromLTWH(0, 0, 540, 1350);
    const framing = Framing(zoom: 1.2, offsetY: 0.1);

    test('mouth corners land on the same spot in before and after', () {
      // "بعد" مصوّرة أقرب، مزاحة ومايلة مقارنة بـ"قبل".
      const before = Photo('b', a: Offset(800, 1500), b: Offset(1300, 1520));
      final angle = 0.2;
      Offset tf(Offset p) {
        final v = (p - const Offset(1000, 1500)) * 1.6;
        return const Offset(1200, 1300) +
            Offset(
              v.dx * math.cos(angle) - v.dy * math.sin(angle),
              v.dx * math.sin(angle) + v.dy * math.cos(angle),
            );
      }

      final after = Photo(
        'a',
        a: tf(before.b!),
        b: tf(before.a!),
      ); // order swapped
      final mb = CellMapping.of(cell, const Size(2000, 3000), before, framing);
      final ma = CellMapping.of(cell, const Size(2400, 3200), after, framing);

      for (final pair in [(before.a!, after.b!), (before.b!, after.a!)]) {
        final pb = mb.map(pair.$1), pa = ma.map(pair.$2);
        expect((pb - pa).distance, lessThan(0.01));
      }
      // Any other feature moved rigidly with the face also lines up.
      const tooth = Offset(1050, 1480);
      expect((mb.map(tooth) - ma.map(tf(tooth))).distance, lessThan(0.01));
      // And the mouth is level and centred horizontally.
      expect(mb.map(before.a!).dy, closeTo(mb.map(before.b!).dy, 0.01));
      expect(
        (mb.map(before.a!).dx + mb.map(before.b!).dx) / 2,
        closeTo(cell.center.dx, 0.01),
      );
    });

    test('cover zoom removes black bars and no less', () {
      const p = Photo('x', a: Offset(250, 700), b: Offset(650, 720));
      const img = Size(900, 1200);
      final z = coverZoom(cell, img, p, 0.1);
      bool covers(double zoom) {
        final m = CellMapping.of(
          cell,
          img,
          p,
          Framing(zoom: zoom, offsetY: 0.1),
        );
        // Inverse-check: every cell corner must come from inside the image.
        final c = math.cos(-m.angle), s = math.sin(-m.angle);
        for (final k in [
          cell.topLeft,
          cell.topRight,
          cell.bottomLeft,
          cell.bottomRight,
        ]) {
          final d = (k - m.target) / m.scale;
          final q = m.mid + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
          if (q.dx < -0.5 ||
              q.dy < -0.5 ||
              q.dx > img.width + 0.5 ||
              q.dy > img.height + 0.5) {
            return false;
          }
        }
        return true;
      }

      expect(covers(z), isTrue);
      expect(covers(z * 0.97), isFalse);
    });

    test('photos without points fill the cell', () {
      final m = CellMapping.of(
        cell,
        const Size(3000, 4000),
        const Photo('x'),
        const Framing(),
      );
      final tl = m.map(Offset.zero), br = m.map(const Offset(3000, 4000));
      expect(tl.dx, lessThanOrEqualTo(0));
      expect(tl.dy, lessThanOrEqualTo(0));
      expect(br.dx, greaterThanOrEqualTo(cell.width));
      expect(br.dy, greaterThanOrEqualTo(cell.height));
    });
  });

  test('Iraqi numbers become international for WhatsApp', () {
    expect(internationalPhone('0770 123 4567'), '9647701234567');
    expect(internationalPhone('+964 770 123 4567'), '9647701234567');
    expect(internationalPhone('00964770'), '964770');
  });

  test('archive survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('rival');
    addTearDown(() => dir.delete(recursive: true));
    final store = Store.instance;
    await store.load(dir: dir);
    final src = File('${dir.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
    final p = await store.addPatient('زينب علي', '07701234567');
    p.cases.add(
      CaseRecord(
        id: '1',
        title: 'فينير',
        created: 0,
        before: Photo(
          await store.importPhoto(src.path),
          a: const Offset(1, 2),
          b: const Offset(3, 4),
        ),
      ),
    );
    await store.save();

    await store.load(dir: dir);
    final loaded = store.patients.single;
    expect(loaded.name, 'زينب علي');
    expect(loaded.cases.single.before!.b, const Offset(3, 4));
    expect(File(loaded.cases.single.before!.path).existsSync(), isTrue);

    await store.deletePatient(loaded);
    await store.load(dir: dir);
    expect(store.patients, isEmpty);
    expect(store.photosDir.listSync(), isEmpty);
  });
}
