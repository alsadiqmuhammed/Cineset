import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rival_clinic/brand.dart';
import 'package:rival_clinic/models.dart';
import 'package:rival_clinic/sheet_io.dart';
import 'package:rival_clinic/store.dart';
import 'package:rival_clinic/xlsx.dart';

/// صف بأعمدة جدول العيادة القديم (أسماء وأرقام وهمية).
List<String> row(Map<String, String> v) => [
  for (final c in kSheetColumns.take(25)) v[c] ?? '',
];

void main() {
  test('xlsx writer and reader agree', () {
    final bytes = writeXlsx([
      const Sheet('ورقة', [
        ['أ', 'ب', '', 'د'],
        ['١٢٣', 'نص <خاص> & "علامات"', 'x', ''],
      ]),
    ]);
    final back = readXlsx(bytes);
    expect(back.single.name, 'ورقة');
    expect(back.single.rows[0], ['أ', 'ب', '', 'د']);
    expect(back.single.rows[1].take(3), ['١٢٣', 'نص <خاص> & "علامات"', 'x']);
  });

  test('notes and teeth from the old system', () {
    expect(
      decodeNote(
        '%D8%AD%D8%B4%D9%88%D8%A9%20%D8%B6%D9%88%D8%A6%D9%8A%D8%A9%20LR6%2B7',
      ),
      'حشوة ضوئية LR6+7',
    );
    expect(decodeNote('Upper%20Arch | Lower%20Arch'), 'Upper Arch\nLower Arch');
    expect(teethFromText('حشوة ضوئية LR6+7 و UL5'), [25, 46, 47]);
    expect(parseSheetDate('NaN--'), isNull);
    expect(parseSheetDate('2026-10-09'), DateTime(2026, 10, 9));
    expect(parseSheetDate('09/10/2026'), DateTime(2026, 10, 9));
  });

  test('import puts every column in its place, export round-trips', () async {
    final dir = await Directory.systemTemp.createTemp('sheet');
    await Store.instance.init(dir: dir);
    final store = Store.instance;
    await store.open(Section.dental);
    final doc = store.doctors.first;
    final bytes = writeXlsx([
      Sheet('المراجعين', [
        kSheetColumns.take(25).toList(),
        row({
          'م': '1',
          'اسم المراجع': 'مراجع تجريبي ',
          'رقم الهاتف': '07700000001',
          'معرّف (ID)': '111',
          'نوع الحالة': 'تيجان و جسور',
          'تاريخ الزيارة': '2026-10-08',
          'مديون': 'نعم',
          'المبلغ المتبقي': '3,150,000',
          'المبلغ المتفق عليه': '4,150,000',
          'حالة العلاج': 'منتهية',
          'أمراض مزمنة': 'ضغط',
          'أدوية': 'علاج ضغط',
          'الجنس': 'ذكر',
          'الميلاد': '1986-05-03',
          'العنوان': 'البصرة-الهارثة',
          'ملاحظات العمل': '%D8%AD%D8%B4%D9%88%D8%A9%20LL6',
          'الحساب': 'DoctorOne',
        }),
        row({
          'اسم المراجع': 'مراجع تجريبي',
          'رقم الهاتف': '07700000001',
          'معرّف (ID)': '111',
          'نوع الحالة': 'حشوة',
          'تاريخ الزيارة': '2026-09-01',
          'المبلغ المتبقي': '0',
          'المبلغ المتفق عليه': '100,000',
          'حالة العلاج': 'مستمرة',
          'الجنس': 'ذكر',
          'الحساب': 'DoctorOne',
        }),
        // نفس الهاتف (عائلة) بس شخص ثاني.
        row({
          'اسم المراجع': 'مراجعة ثانية',
          'رقم الهاتف': '07700000001',
          'معرّف (ID)': '222',
          'نوع الحالة': 'فحص',
          'تاريخ الزيارة': '2026-09-02',
          'المبلغ المتبقي': '0',
          'حالة العلاج': 'منتهية',
          'الجنس': 'انثى',
          'الميلاد': 'NaN--',
          'الحساب': 'DoctorOne',
        }),
      ]),
    ]);
    final plan = readPatientsSheet(bytes);
    expect(plan.patients.length, 2);
    expect(plan.cases, 3);
    expect(plan.doctors, {'DoctorOne': 3});
    final r = await applyImport(plan, {'DoctorOne': doc.id});
    expect((r.newPatients, r.newCases), (2, 3));

    final p = store.patients.firstWhere((p) => p.externalId == '111');
    expect(p.name, 'مراجع تجريبي');
    expect(p.gender, Gender.male);
    expect(
      DateTime.fromMillisecondsSinceEpoch(p.birthDate!),
      DateTime(1986, 5, 3),
    );
    expect(
      (p.address, p.conditions, p.medications),
      ('البصرة-الهارثة', 'ضغط', 'علاج ضغط'),
    );
    expect(p.hasMedicalAlert, isTrue);
    final crown = p.cases.firstWhere((c) => c.title == 'تيجان و جسور');
    expect((crown.price, crown.paid, crown.due), (4150000, 1000000, 3150000));
    expect(crown.status, CaseStatus.done);
    expect(crown.doctorId, doc.id);
    expect(crown.note, 'حشوة LL6');
    expect(crown.teeth, [36]);
    expect(
      p.cases.firstWhere((c) => c.title == 'حشوة').status,
      CaseStatus.active,
    );
    final sister = store.patients.firstWhere((p) => p.externalId == '222');
    expect((sister.gender, sister.birthDate), (Gender.female, null));
    expect(sister.cases.single.price, isNull);

    // التصدير بنفس الأعمدة، والاستيراد مرة ثانية ما يكرر.
    final out = exportPatientsSheet();
    final sheets = readXlsx(out);
    expect(sheets.first.rows.first.take(25), kSheetColumns.take(25));
    expect((await applyImport(readPatientsSheet(out), {})).newCases, 0);
    expect((await applyImport(readPatientsSheet(bytes), {})).newCases, 0);
    expect(store.allCases.length, 3);
  });
}
