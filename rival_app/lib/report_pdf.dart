import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show
        BuildContext,
        showDialog,
        AlertDialog,
        Row,
        CircularProgressIndicator,
        SizedBox,
        Text,
        Navigator,
        showModalBottomSheet,
        Padding,
        EdgeInsets,
        Column,
        MainAxisSize,
        CrossAxisAlignment,
        FilledButton,
        Icon,
        Icons,
        Expanded,
        OutlinedButton,
        TextStyle,
        FontWeight;
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'brand.dart';
import 'models.dart';
import 'render.dart';
import 'screens/common.dart' show toast;
import 'screens/design_controls.dart' show shareFile;
import 'stats.dart';
import 'store.dart';

/// تقارير PDF بهوية القسم (خط تجوال، ألوان القسم، الشعار الأفقي).
class _Kit {
  final Brand b;
  final pw.Font regular, bold, extra;
  final pw.MemoryImage logo;
  _Kit(this.b, this.regular, this.bold, this.extra, this.logo);

  static Future<_Kit> load(Brand b) async {
    Future<pw.Font> font(String f) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$f'));
    final logo = await rootBundle.load(b.logoHorizontal);
    return _Kit(
      b,
      await font('Tajawal-Regular.ttf'),
      await font('Tajawal-Bold.ttf'),
      await font('Tajawal-ExtraBold.ttf'),
      pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }

  PdfColor c(ui.Color color) => PdfColor.fromInt(color.toARGB32());
  PdfColor get primary => c(b.primary);
  PdfColor get accent => c(b.accent);
  PdfColor get text => c(b.text);
  PdfColor get muted => c(b.muted);
  PdfColor get line => c(b.line);
  PdfColor get soft => c(b.bg);

  pw.TextStyle t(double size, {pw.Font? font, PdfColor? color}) =>
      pw.TextStyle(font: font ?? regular, fontSize: size, color: color ?? text);

  pw.Document doc(String title) => pw.Document(
    title: title,
    author: b.latinName,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.MultiPage page(
    String title,
    List<pw.Widget> Function() body,
  ) => pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
    header: (ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primary, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, height: 30),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title,
                style: t(11, font: bold, color: primary),
              ),
              pw.Text(
                'صدر ${arDate(DateTime.now().millisecondsSinceEpoch)}',
                style: t(8, color: muted),
              ),
            ],
          ),
        ],
      ),
    ),
    footer: (ctx) {
      final clinic = Store.instance.clinic;
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: line)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '${b.name} · ${clinic.address}${clinic.phones.isEmpty ? '' : ' · ${clinic.phones.join(' / ')}'}',
                style: t(7.5, color: muted),
              ),
            ),
            pw.Text(
              '${ar(ctx.pageNumber)} / ${ar(ctx.pagesCount)}',
              style: t(8, color: muted),
            ),
          ],
        ),
      );
    },
    build: (_) => body(),
  );

  pw.Widget title(String first, String second) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(first, style: t(24, font: extra)),
      pw.Text(
        second,
        style: t(20, font: extra, color: primary),
      ),
      pw.SizedBox(height: 14),
    ],
  );

  pw.Widget section(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
    child: pw.Row(
      children: [
        pw.Container(width: 3, height: 13, color: primary),
        pw.SizedBox(width: 6),
        pw.Text(s, style: t(12.5, font: bold)),
      ],
    ),
  );

  /// شبكة معلومات بعمودين: (العنوان، القيمة).
  pw.Widget info(List<(String, String)> items) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        pw.Row(
          children: [
            for (final it in items.skip(i).take(2))
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.all(3),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color: soft,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(it.$1, style: t(8, color: muted)),
                      pw.Text(
                        it.$2.isEmpty ? '—' : it.$2,
                        style: t(10.5, font: bold),
                      ),
                    ],
                  ),
                ),
              ),
            if (items.length - i == 1) pw.Expanded(child: pw.SizedBox()),
          ],
        ),
      );
    }
    return pw.Column(children: rows);
  }

  /// بطاقات أرقام (مثل لوحة الإحصائيات).
  pw.Widget kpis(List<(String, String)> items) => pw.Row(
    children: [
      for (final (value, label) in items)
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.all(3),
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: line),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  value,
                  style: t(18, font: extra, color: primary),
                ),
                pw.Text(label, style: t(8.5, color: muted)),
              ],
            ),
          ),
        ),
    ],
  );

  /// جدول بسيط بعناوين ملوّنة.
  pw.Widget table(
    List<String> head,
    List<List<String>> rows, {
    List<int>? flex,
  }) {
    final f = flex ?? List.filled(head.length, 1);
    pw.Widget row(
      List<String> cells, {
      bool header = false,
      bool shade = false,
    }) => pw.Container(
      color: header ? primary : (shade ? soft : null),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            pw.Expanded(
              flex: f[i],
              child: pw.Text(
                cells[i],
                style: header ? t(9, font: bold, color: PdfColors.white) : t(9),
              ),
            ),
        ],
      ),
    );
    return pw.Column(
      children: [
        row(head, header: true),
        for (var i = 0; i < rows.length; i++) row(rows[i], shade: i.isOdd),
      ],
    );
  }

  /// أشرطة نسبية (للعلاجات والأطباء).
  pw.Widget bars(Map<String, int> data, int total) {
    final entries = data.entries.take(10).toList();
    final max = entries.isEmpty ? 1 : entries.first.value;
    return pw.Column(
      children: [
        for (final e in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 110, child: pw.Text(e.key, style: t(9))),
                pw.Expanded(
                  child: pw.Stack(
                    children: [
                      pw.Container(
                        height: 9,
                        decoration: pw.BoxDecoration(
                          color: soft,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                      ),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            flex: (1000 * e.value / max).round().clamp(1, 1000),
                            child: pw.Container(
                              height: 9,
                              decoration: pw.BoxDecoration(
                                color: primary,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          if (e.value < max)
                            pw.Expanded(
                              flex: (1000 - 1000 * e.value / max).round().clamp(
                                1,
                                1000,
                              ),
                              child: pw.SizedBox(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 60,
                  child: pw.Text(
                    '${ar((100 * e.value / (total == 0 ? 1 : total)).round())}٪ · ${ar(e.value)}',
                    textAlign: pw.TextAlign.left,
                    style: t(8.5, color: muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget note(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: soft,
      border: pw.Border(right: pw.BorderSide(color: accent, width: 3)),
    ),
    child: pw.Text(text, style: t(10)),
  );
}

Future<Uint8List?> _composite(CaseRecord c, Brand b) async {
  final img = await renderReportComposite(c, b);
  if (img == null) return null;
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

String _patientLine(Patient p, Brand b) => [
  if (p.age != null) '${ar(p.age!)} سنة',
  if (p.gender != null && !b.feminine) p.gender!.label,
].join(' · ');

List<pw.Widget> _caseBody(
  _Kit k,
  Patient p,
  CaseRecord c,
  Uint8List? photo, {
  bool full = true,
}) {
  final b = k.b;
  final doctor = Store.instance.doctor(c.doctorId);
  return [
    k.info([
      (b.f('المراجع', 'المراجعة'), p.name),
      ('العمر', _patientLine(p, b)),
      ('الطبيب', doctor?.name ?? ''),
      (b.teethChart ? 'العلاج' : 'الجلسة', c.title),
      ('تاريخ البدء', arDate(c.created)),
      ('الحالة', c.status.label),
      if (c.completed != null) ('تاريخ الإكمال', arDate(c.completed!)),
      (b.teethChart ? 'الزيارات' : 'الجلسات', ar(c.visits.length)),
    ]),
    if (photo != null) ...[
      k.section('قبل وبعد'),
      pw.ClipRRect(
        horizontalRadius: 10,
        verticalRadius: 10,
        child: pw.Image(pw.MemoryImage(photo), height: full ? 330 : 200),
      ),
    ],
    if (c.teeth.isNotEmpty) ...[
      k.section('الأسنان المعالجة (ترقيم FDI)'),
      pw.Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final t in c.teeth)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: pw.BoxDecoration(
                color: k.primary,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                '$t',
                style: k.t(9, font: k.bold, color: PdfColors.white),
              ),
            ),
        ],
      ),
    ],
    if (c.areas.isNotEmpty) ...[
      k.section('المناطق المعالجة'),
      pw.Text(c.areas.join('، '), style: k.t(10)),
    ],
    if (full && c.visits.isNotEmpty) ...[
      k.section(b.teethChart ? 'سجل الزيارات' : 'سجل الجلسات'),
      k.table(
        ['#', 'التاريخ', 'شنو انسوّى'],
        [
          for (final (i, v) in c.visits.indexed)
            [ar(i + 1), arDate(v.date), v.note],
        ],
        flex: [1, 3, 8],
      ),
    ],
    if (c.note.isNotEmpty) ...[k.section('ملاحظات الطبيب'), k.note(c.note)],
  ];
}

Future<File> _save(pw.Document doc, String name) async {
  final dir = Store.instance.exportsDir.path;
  final safe = name.replaceAll(RegExp(r'[^\w؀-ۿ]+'), '_');
  final f = File('$dir/$safe.pdf');
  await f.writeAsBytes(await doc.save());
  return f;
}

/// تقرير حالة واحدة.
Future<File> caseReport(Brand b, Patient p, CaseRecord c) async {
  final k = await _Kit.load(b);
  final photo = await _composite(c, b);
  final doc = k.doc('تقرير حالة - ${p.name}');
  doc.addPage(
    k.page(
      'تقرير حالة',
      () => [
        k.title('تقرير حالة', '${c.title} · ${p.name}'),
        ..._caseBody(k, p, c, photo),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('توقيع الطبيب: ____________________', style: k.t(10)),
            pw.Text('الختم', style: k.t(10, color: k.muted)),
          ],
        ),
      ],
    ),
  );
  return _save(doc, 'تقرير_${p.name}_${c.title}');
}

/// ملف المراجع كامل بكل حالاته.
Future<File> patientReport(Brand b, Patient p) async {
  final k = await _Kit.load(b);
  final photos = <String, Uint8List?>{
    for (final c in p.cases) c.id: await _composite(c, b),
  };
  final doc = k.doc('ملف ${p.name}');
  doc.addPage(
    k.page(
      'ملف ${b.f('المراجع', 'المراجعة')}',
      () => [
        k.title('ملف ${b.f('المراجع', 'المراجعة')}', p.name),
        k.info([
          ('رقم الهاتف', p.phone),
          ('العمر', _patientLine(p, b)),
          ('أول زيارة', arDate(p.created)),
          ('عدد الحالات', ar(p.cases.length)),
        ]),
        if (p.notes.isNotEmpty) ...[k.section('ملاحظات عامة'), k.note(p.notes)],
        for (final c in p.cases) ...[
          k.section('${c.title} · ${arDate(c.created)}'),
          ..._caseBody(k, p, c, photos[c.id], full: false),
        ],
      ],
    ),
  );
  return _save(doc, 'ملف_${p.name}');
}

/// تقرير الطبيب: نبذته وأرقامه وقائمة حالاته.
Future<File> doctorReport(Brand b, Doctor d, Stats s) async {
  final k = await _Kit.load(b);
  final doc = k.doc('تقرير ${d.name}');
  doc.addPage(
    k.page(
      'تقرير الطبيب',
      () => [
        k.title(d.name, d.specialty),
        if (d.services.isNotEmpty)
          pw.Text('الخدمات: ${d.services.join('، ')}', style: k.t(10)),
        if (d.bio.isNotEmpty) ...[k.section('نبذة'), k.note(d.bio)],
        k.section('بالأرقام'),
        k.kpis([
          (ar(s.total), 'حالة'),
          (ar(s.patients), b.patients),
          (ar(s.done), 'مكتملة'),
          (ar(s.active), 'قيد العلاج'),
        ]),
        if (s.byTreatment.isNotEmpty) ...[
          k.section('حسب العلاج'),
          k.bars(s.byTreatment, s.total),
        ],
        if (s.cases.isNotEmpty) ...[
          k.section('الحالات'),
          _caseTable(k, s, withDoctor: false),
        ],
      ],
    ),
  );
  return _save(doc, 'تقرير_${d.name}');
}

pw.Widget _caseTable(_Kit k, Stats s, {bool withDoctor = true}) {
  final b = k.b;
  return k.table(
    [
      b.f('المراجع', 'المراجعة'),
      'العلاج',
      if (withDoctor) 'الطبيب',
      'التاريخ',
      'الحالة',
    ],
    [
      for (final (p, c) in s.cases)
        [
          p.name,
          c.title,
          if (withDoctor) s.doctorNames[c.doctorId] ?? '—',
          arDate(c.created),
          c.status.label,
        ],
    ],
    flex: withDoctor ? [4, 4, 4, 4, 3] : [4, 4, 4, 3],
  );
}

/// التقرير الكامل للقسم لفترة معيّنة.
Future<File> clinicReport(
  Brand b,
  Stats s, {
  required Period period,
  Doctor? doctor,
}) async {
  final k = await _Kit.load(b);
  final monthly = Stats(
    s.cases,
    s.doctorNames,
  ).monthly(period == Period.all || period == Period.year ? 12 : 3);
  final doc = k.doc('تقرير ${b.name}');
  final scope = [period.label, if (doctor != null) doctor.name].join(' · ');
  doc.addPage(
    k.page(
      'التقرير الشامل',
      () => [
        k.title('التقرير الشامل', '${b.name} · $scope'),
        k.kpis([
          (ar(s.total), 'حالة'),
          (ar(s.patients), b.patients),
          (ar(s.active), 'قيد العلاج'),
          (ar(s.done), 'مكتملة'),
        ]),
        k.kpis([
          (ar(s.withBeforeAfter), 'بيها قبل وبعد'),
          (ar(s.visits), b.teethChart ? 'زيارة' : 'جلسة'),
          (
            s.avgDays == null ? '—' : ar(s.avgDays!.round()),
            'يوم متوسط العلاج',
          ),
          (
            s.total == 0 ? '—' : '${ar((100 * s.done / s.total).round())}٪',
            'نسبة الإكمال',
          ),
        ]),
        k.section(b.teethChart ? 'حسب العلاج' : 'حسب الجلسة'),
        k.bars(s.byTreatment, s.total),
        if (doctor == null && s.byDoctor.isNotEmpty) ...[
          k.section('حسب الطبيب'),
          k.bars(s.byDoctor, s.total),
        ],
        if (s.byArea.isNotEmpty) ...[
          k.section('حسب المنطقة'),
          k.bars(s.byArea, s.total),
        ],
        k.section('الحالات الجديدة شهرياً'),
        k.table(
          ['الشهر', 'عدد الحالات'],
          [
            for (final (y, m, n) in monthly)
              ['${arMonths[m - 1]} ${ar(y)}', ar(n)],
          ],
          flex: [3, 2],
        ),
        k.section('قائمة الحالات'),
        _caseTable(k, s, withDoctor: doctor == null),
      ],
    ),
  );
  return _save(doc, 'تقرير_${b.latinName}_${period.name}');
}

/// يبني التقرير ويعرض خيارات الفتح والمشاركة.
Future<void> shareReport(
  BuildContext context,
  Future<File> Function() build,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('جاري تجهيز التقرير...'),
        ],
      ),
    ),
  );
  File file;
  try {
    file = await build();
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      toast(context, 'ما تجهّز التقرير: $e');
    }
    return;
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  await showModalBottomSheet(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'التقرير جاهز',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => OpenFilex.open(file.path),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => shareFile(file.path),
                  icon: const Icon(Icons.share),
                  label: const Text('مشاركة / طباعة'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
