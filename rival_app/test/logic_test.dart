import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/render.dart';
import 'package:rival_clinic/screens/appointments_screen.dart';
import 'package:rival_clinic/screens/patient_screen.dart';
import 'package:rival_clinic/stats.dart';
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
      final z = coverZoom(cell, img, p, const Framing(offsetY: 0.1));
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

  group('store', () {
    late Directory dir;
    final store = Store.instance;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rival');
      await store.init(dir: dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('archive survives a restart', () async {
      await store.open(Section.dental);
      final src = File('${dir.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
      final p = await store.addPatient('زينب علي', '07701234567');
      p.cases.add(
        CaseRecord(
          id: '1',
          title: 'فينير',
          created: 0,
          doctorId: 'd1',
          teeth: [11, 21],
          visits: [Visit(id: 'v', date: 5, note: 'تحضير')],
          before: Photo(
            await store.importPhoto(src.path),
            a: const Offset(1, 2),
            b: const Offset(3, 4),
          ),
        ),
      );
      await store.save();

      await store.open(Section.dental);
      final c = store.patients.single.cases.single;
      expect(store.patients.single.name, 'زينب علي');
      expect(c.before!.b, const Offset(3, 4));
      expect(c.teeth, [11, 21]);
      expect(c.visits.single.note, 'تحضير');
      expect(store.doctor(c.doctorId)!.name, 'د. مصطفى عبد الكريم');
      expect(File(c.before!.path).existsSync(), isTrue);

      await store.deletePatient(store.patients.single);
      await store.open(Section.dental);
      expect(store.patients, isEmpty);
      expect(store.photosDir.listSync(), isEmpty);
    });

    test('dental and beauty keep separate archives and teams', () async {
      await store.open(Section.dental);
      await store.addPatient('أحمد', '');
      expect(store.doctors, hasLength(5));

      await store.open(Section.beauty);
      expect(store.patients, isEmpty);
      expect(store.doctors.single.name, 'د. حنين عبد الكريم');
      expect(store.doctors.single.services, contains('بوتوكس'));
      final p = await store.addPatient('سارة', '');
      expect(p.gender, Gender.female);

      await store.open(Section.dental);
      expect(store.patients.single.name, 'أحمد');
      expect(store.clinic.phones, contains('0776 172 0720'));
    });

    test('data from the first version moves into the dental section', () async {
      final photos = Directory('${dir.path}/photos')..createSync();
      final photo = File('${photos.path}/1.jpg')..writeAsBytesSync([9]);
      File('${dir.path}/patients.json').writeAsStringSync(
        '[{"id":"1","name":"قديم","phone":"","created":0,"cases":[{"id":"c","title":"تقويم","created":0,"before":{"path":"${photo.path}"}}]}]',
      );
      await store.init(dir: dir);
      await store.open(Section.dental);
      final c = store.patients.single.cases.single;
      expect(store.patients.single.name, 'قديم');
      expect(c.status, CaseStatus.active);
      expect(File(c.before!.path).readAsBytesSync(), [9]);
      expect(c.before!.path, contains('/dental/photos/'));
    });

    test('backup restores both sections with working photo paths', () async {
      await store.open(Section.beauty);
      final src = File('${dir.path}/s.jpg')..writeAsBytesSync([7, 7]);
      final p = await store.addPatient('مريم', '');
      p.cases.add(
        CaseRecord(
          id: 'x',
          title: 'فلر',
          created: 0,
          after: Photo(await store.importPhoto(src.path)),
        ),
      );
      await store.save();
      final zip = await store.exportBackup();
      final saved = File(zip).readAsBytesSync();

      // تلفون جديد: مجلد مختلف تماماً.
      final other = await Directory.systemTemp.createTemp('rival2');
      addTearDown(() => other.delete(recursive: true));
      await store.init(dir: other);
      await store.open(Section.beauty);
      expect(store.patients, isEmpty);
      final copy = File('${other.path}/b.zip')..writeAsBytesSync(saved);
      await store.restoreBackup(copy.path);

      final c = store.patients.single.cases.single;
      expect(c.after!.path, startsWith(other.path));
      expect(File(c.after!.path).readAsBytesSync(), [7, 7]);
    });

    test('statistics by period, treatment and doctor', () async {
      await store.open(Section.dental);
      final now = DateTime(2026, 10, 8);
      final p = await store.addPatient('علي', '');
      int at(int month) => DateTime(2026, month, 3).millisecondsSinceEpoch;
      p.cases.addAll([
        CaseRecord(id: '1', title: 'تقويم', created: at(10), doctorId: 'd1'),
        CaseRecord(
          id: '2',
          title: 'تقويم',
          created: at(9),
          doctorId: 'd1',
          status: CaseStatus.done,
          completed: at(9) + 10 * 86400000,
        ),
        CaseRecord(id: '3', title: 'تبييض', created: at(2), doctorId: 'd3'),
      ]);
      final month = Stats.of(store, period: Period.month, now: now);
      expect(month.total, 1);
      final all = Stats.of(store, now: now);
      expect(all.byTreatment, {'تقويم': 2, 'تبييض': 1});
      expect(all.byDoctor['د. مصطفى عبد الكريم'], 2);
      expect(all.avgDays, 10);
      expect(Stats.of(store, doctorId: 'd3').total, 1);
      expect(all.monthly(3, now: now).map((m) => m.$3), [0, 1, 1]);
    });
  });

  group('money', () {
    test('amounts are written and read in Arabic', () {
      expect(money(250000), '٢٥٠٬٠٠٠ د.ع');
      expect(money(1500), '١٬٥٠٠ د.ع');
      expect(money(900), '٩٠٠ د.ع');
      expect(money(-5000), '-٥٬٠٠٠ د.ع');
      expect(parseAmount('٢٥٠٠٠٠'), 250000);
      expect(parseAmount('250,000'), 250000);
      expect(parseAmount('٢٥٠ ألف'), 250000);
      expect(parseAmount('1.5 مليون'), 1500000);
      expect(parseAmount('١٫٥ مليون'), 1500000);
      expect(parseAmount(''), isNull);
      expect(parseAmount('بدون'), isNull);
    });

    test('appointment time is shown only when set', () {
      final day = DateTime(2026, 10, 12).millisecondsSinceEpoch;
      final evening = DateTime(2026, 10, 12, 17, 30).millisecondsSinceEpoch;
      expect(arDateTime(day), arDate(day));
      expect(arDateTime(evening), '${arDate(day)} · ٥:٣٠ م');
      expect(arTime(DateTime(2026, 1, 1, 9, 5)), '٩:٠٥ ص');
      expect(arTime(DateTime(2026, 1, 1, 12, 0)), '١٢:٠٠ م');
    });

    test('payments, balance, income and who still owes', () {
      final now = DateTime(2026, 10, 9);
      int at(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;
      final c1 = CaseRecord(
        id: 'c1',
        title: 'زراعة',
        created: at(2026, 8, 1),
        doctorId: 'd1',
        price: 1000000,
        payments: [
          Payment(id: 'p1', date: at(2026, 8, 1), amount: 400000),
          Payment(id: 'p2', date: at(2026, 10, 2), amount: 100000),
        ],
      );
      final c2 = CaseRecord(
        id: 'c2',
        title: 'تبييض',
        created: at(2026, 10, 3),
        doctorId: 'd2',
        price: 150000,
        payments: [Payment(id: 'p3', date: at(2026, 10, 3), amount: 150000)],
      );
      final c3 = CaseRecord(id: 'c3', title: 'فحص', created: at(2026, 10, 4));
      expect(c1.paid, 500000);
      expect(c1.due, 500000);
      expect(c2.due, 0);
      expect(c3.due, isNull);
      // ترجع سليمة من JSON.
      final back = CaseRecord.fromJson(c1.toJson());
      expect(back.price, 1000000);
      expect(back.payments.map((p) => p.amount), [400000, 100000]);
      expect(CaseRecord.fromJson(c3.toJson()).payments, isEmpty);

      final p = Patient(
        id: 'p',
        name: 'علي',
        phone: '',
        created: 0,
        cases: [c1, c2, c3],
      );
      final all = [for (final c in p.cases) (p, c)];
      final month = Stats(
        all
            .where(
              (e) =>
                  e.$2.created >=
                  DateTime(now.year, now.month).millisecondsSinceEpoch,
            )
            .toList(),
        {'d1': 'د. علي', 'd2': 'د. سارة'},
        from: DateTime(now.year, now.month),
        all: all,
      );
      // واردات الشهر حسب تاريخ الدفعة: ١٠٠ ألف من حالة قديمة + ١٥٠ ألف.
      expect(month.income, 250000);
      expect(month.outstanding, 500000);
      expect(month.owing.single.$2.id, 'c1');
      expect(month.billed, 150000);
      expect(month.incomeByDoctor, {'د. سارة': 150000, 'د. علي': 100000});
      final m = month.monthlyIncome(3, now: now);
      expect(m.map((e) => e.$3), [400000, 0, 250000]);
    });
  });

  test('Arabic digits and spelling variants', () {
    expect(latinDigits('٠٧٧٠ ١٢٣ ۴۵۶'), '0770 123 456');
    expect(internationalPhone('٠٧٧٠١٢٣٤٥٦٧'), '9647701234567');
    expect(searchKey('إسراء'), searchKey('اسراء'));
    expect(searchKey('فاطمة'), searchKey('فاطمه'));
    expect(searchKey('٠٧٧٠ ١٢٣'), '0770123');
  });

  group('birthdays and appointments', () {
    Patient born(DateTime d) => Patient(
      id: 'p',
      name: 'زينب علي',
      phone: '',
      created: 0,
      birthDate: d.millisecondsSinceEpoch,
    );

    test('days to the next birthday, age and leap day', () {
      final now = DateTime(2026, 10, 9, 15);
      expect(born(DateTime(1990, 10, 9)).daysToBirthday(now), 0);
      expect(born(DateTime(1990, 10, 12)).daysToBirthday(now), 3);
      expect(born(DateTime(1990, 10, 8)).daysToBirthday(now), 364);
      expect(born(DateTime(2000, 2, 29)).daysToBirthday(DateTime(2027, 2, 28)), 0);
      final p = born(DateTime(1990, 12, 31));
      expect(p.age, DateTime.now().year - 1991 + (DateTime.now().month == 12 && DateTime.now().day == 31 ? 1 : 0));
      final restored = Patient.fromJson(p.toJson());
      expect(restored.birthDate, p.birthDate);
    });

    test('close appointments for the same doctor are flagged', () {
      final p = Patient(id: 'p', name: 'x', phone: '', created: 0);
      CaseRecord at(String id, DateTime t, String doc) => CaseRecord(
        id: id,
        title: 't',
        created: 0,
        doctorId: doc,
        nextVisit: t.millisecondsSinceEpoch,
      );
      final list = [
        (p, at('a', DateTime(2026, 1, 1, 17, 0), 'd1')),
        (p, at('b', DateTime(2026, 1, 1, 17, 20), 'd1')),
        (p, at('c', DateTime(2026, 1, 1, 17, 10), 'd2')),
        (p, at('d', DateTime(2026, 1, 1, 19, 0), 'd1')),
        (p, at('e', DateTime(2026, 1, 1), 'd1')),
      ];
      expect(appointmentConflicts(list), {'a', 'b'});
    });
  });
}
