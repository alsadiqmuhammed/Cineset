import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/charts.dart';
import 'package:rival_clinic/insights.dart';
import 'package:rival_clinic/models.dart';

void main() {
  const size = Size(800, 800);

  group('tooth chart', () {
    ToothSpot spot(int t, {bool primary = false}) =>
        toothLayout(size, primary: primary).firstWhere((s) => s.fdi == t);

    test('FDI order as the dentist faces the patient', () {
      // يمين المراجع (الربع ١ و٤) على يسار الشاشة.
      expect(spot(18).center.dx, lessThan(spot(11).center.dx));
      expect(spot(11).center.dx, lessThan(spot(21).center.dx));
      expect(spot(21).center.dx, lessThan(spot(28).center.dx));
      expect(spot(48).center.dx, lessThan(spot(38).center.dx));
      // العلوي فوق والسفلي جوّه، والقواطع بالوسط.
      expect(spot(11).center.dy, lessThan(spot(41).center.dy));
      expect(spot(11).center.dy, lessThan(spot(16).center.dy));
      expect(spot(41).center.dy, greaterThan(spot(46).center.dy));
      expect((spot(11).center.dx + spot(21).center.dx) / 2, closeTo(400, 2));
    });

    test('every tooth is tappable and no two teeth overlap', () {
      for (final primary in [false, true]) {
        final spots = toothLayout(size, primary: primary);
        expect(spots, hasLength(primary ? 20 : 32));
        for (final s in spots) {
          expect(toothAt(size, s.center, primary: primary), s.fdi);
        }
        for (var i = 0; i < spots.length; i++) {
          for (var j = i + 1; j < spots.length; j++) {
            final a = spots[i], b = spots[j];
            final minGap = (a.width + b.width) / 2 * 0.8;
            expect(
              (a.center - b.center).distance,
              greaterThan(minGap),
              reason: '${a.fdi} vs ${b.fdi}',
            );
          }
        }
      }
      expect(toothAt(size, const Offset(400, 400), primary: false), isNull);
    });

    test('tooth names and summary', () {
      expect(toothName(11), 'قاطع مركزي علوي أيمن');
      expect(toothName(36), 'رحى أولى سفلي أيسر');
      expect(toothName(48), 'ضرس العقل سفلي أيمن');
      expect(toothName(54), 'رحى أولى لبنية علوي أيمن');
      expect(teethSummary([11, 21, 36]), '٢ أمامية علوية، ١ خلفية سفلية');
    });
  });

  group('face map', () {
    const s = Size(400, 500);
    test(
      'each area is found at its centre, right side on the viewer\'s left',
      () {
        for (final a in faceAreas) {
          expect(faceAreaAt(s, a.rect(s).center), a.id);
        }
        final r = faceAreas.firstWhere((a) => a.id == 'cheek_r').rect(s);
        final l = faceAreas.firstWhere((a) => a.id == 'cheek_l').rect(s);
        expect(r.center.dx, lessThan(l.center.dx));
        expect(faceAreaAt(s, const Offset(5, 5)), isNull);
      },
    );

    test('old free-text areas become map areas', () {
      final c = CaseRecord.fromJson({
        'id': '1',
        'title': 'فلر',
        'created': 0,
        'areas': ['الشفايف', 'الجبهة', 'منطقة ثانية'],
      });
      expect(c.areas, ['lips', 'forehead', 'منطقة ثانية']);
      expect(areaLabel('lips'), 'الشفايف');
      expect(areaLabel('منطقة ثانية'), 'منطقة ثانية');
      c.doses['lips'] = '١ مل';
      expect(CaseRecord.fromJson(c.toJson()).doses, {'lips': '١ مل'});
    });
  });

  group('smart summary', () {
    final now = DateTime(2026, 10, 8);
    int day(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;
    final p = Patient(
      id: 'p',
      name: 'زينب',
      phone: '',
      created: day(60),
      birthYear: 1998,
    );
    final d = Doctor(id: 'd', name: 'د. مصطفى');

    test('dental case in treatment', () {
      final c = CaseRecord(
        id: 'c',
        title: 'فينير',
        created: day(45),
        teeth: [11, 21],
        visits: [Visit(id: 'v', date: day(10))],
        nextVisit: now.add(const Duration(days: 5)).millisecondsSinceEpoch,
      );
      final s = caseSummary(dental, p, c, d, now: now);
      expect(s, contains('حالة فينير للمراجع زينب (٢٨ سنة) بإشراف د. مصطفى'));
      expect(s, contains('قيد العلاج من ٤٥ يوم'));
      expect(s, contains('تمت ١ زيارة'));
      expect(s, contains('٢ أمامية علوية'));
      expect(s, contains('المراجعة القادمة'));
      expect(CaseFacts.of(c, now: now).daysToNext, 5);
      expect(
        caseAlerts(dental, c, now: now),
        contains('ماكو صورة "قبل" للحالة.'),
      );
    });

    test('completed beauty case', () {
      final c = CaseRecord(
        id: 'c',
        title: 'فلر',
        created: day(30),
        status: CaseStatus.done,
        completed: day(2),
        areas: ['lips'],
        doses: {'lips': '١ مل'},
      );
      final s = caseSummary(beauty, p, c, null, now: now);
      expect(s, startsWith('جلسة فلر للمراجعة زينب'));
      expect(s, contains('خلال ٢٨ يوم'));
      expect(s, contains('الشفايف (١ مل)'));
      expect(
        caseAlerts(beauty, c, now: now),
        contains('الحالة مكتملة بدون صورة "بعد".'),
      );
    });

    test('stale case asks for follow-up', () {
      final c = CaseRecord(
        id: 'c',
        title: 'تقويم',
        created: day(90),
        teeth: [11],
      );
      expect(
        caseAlerts(dental, c, now: now).any((a) => a.contains('تحتاج متابعة')),
        isTrue,
      );
    });
  });
}
