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
        FontWeight,
        Size;
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'brand.dart';
import 'charts.dart';
import 'insights.dart';
import 'models.dart';
import 'render.dart';
import 'screens/common.dart' show toast;
import 'screens/design_controls.dart' show shareFile;
import 'stats.dart';
import 'store.dart';

const _side = 34.0;

/// تقارير PDF بهوية القسم: شريط ملوّن بالشعار المعكوس، خط تجوال، كروت بحواف ناعمة،
/// خريطة الأسنان أو الوجه، وخط زمني للزيارات.
class _Kit {
  final Brand b;
  final pw.Font regular, bold, extra;
  final pw.MemoryImage logo, logoReversed;
  _Kit(
    this.b,
    this.regular,
    this.bold,
    this.extra,
    this.logo,
    this.logoReversed,
  );

  static Future<_Kit> load(Brand b) async {
    Future<pw.Font> font(String f) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$f'));
    Future<pw.MemoryImage> img(String a) async =>
        pw.MemoryImage((await rootBundle.load(a)).buffer.asUint8List());
    return _Kit(
      b,
      await font('Tajawal-Regular.ttf'),
      await font('Tajawal-Bold.ttf'),
      await font('Tajawal-ExtraBold.ttf'),
      await img(b.logoHorizontal),
      await img(b.logoReversed),
    );
  }

  PdfColor c(ui.Color color) => PdfColor.fromInt(color.toARGB32());
  PdfColor get primary => c(b.primary);
  PdfColor get deep => c(b.primaryDeep);
  PdfColor get accent => c(b.accent);
  PdfColor get text => c(b.text);
  PdfColor get muted => c(b.muted);
  PdfColor get line => c(b.line);
  PdfColor get soft => c(b.bg);
  PdfColor get dark => c(b.dark);

  pw.TextStyle t(
    double size, {
    pw.Font? font,
    PdfColor? color,
    double? height,
  }) => pw.TextStyle(
    font: font ?? regular,
    fontSize: size,
    color: color ?? text,
    lineSpacing: height,
  );

  pw.Document doc(String title) => pw.Document(
    title: title,
    author: b.latinName,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  /// صفحة بشريط علوي ملوّن بالصفحة الأولى، وترويسة بسيطة بالباقي.
  pw.MultiPage page({
    required String title,
    required String subtitle,
    required List<pw.Widget> Function() body,
  }) => pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.only(bottom: 26),
      textDirection: pw.TextDirection.rtl,
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: -60,
              bottom: -60,
              child: pw.Container(
                width: 220,
                height: 220,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: accent.shade(0.15), width: 0.8),
                ),
              ),
            ),
            pw.Positioned(
              left: -20,
              bottom: -20,
              child: pw.Container(
                width: 140,
                height: 140,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: accent.shade(0.1), width: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    header: (ctx) => ctx.pageNumber == 1
        ? _band(title, subtitle)
        : pw.Container(
            margin: const pw.EdgeInsets.fromLTRB(_side, 22, _side, 12),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primary, width: 1.5),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Image(logo, height: 22),
                pw.Spacer(),
                pw.Text(
                  '$title · $subtitle',
                  style: t(9, font: bold, color: primary),
                ),
              ],
            ),
          ),
    footer: (ctx) {
      final clinic = Store.instance.clinic;
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: _side),
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
    build: (_) => [
      for (final w in body())
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: _side),
          child: w,
        ),
    ],
  );

  pw.Widget _band(String title, String subtitle) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 18),
    padding: const pw.EdgeInsets.fromLTRB(_side, 26, _side, 22),
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        begin: pw.Alignment.topRight,
        end: pw.Alignment.bottomLeft,
        colors: [primary, deep, dark],
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: t(24, font: extra, color: PdfColors.white),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: t(13, font: bold, color: accent),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'صدر بتاريخ ${arDate(DateTime.now().millisecondsSinceEpoch)}',
                style: t(8.5, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.Image(logoReversed, height: 64),
      ],
    ),
  );

  pw.Widget section(String s, {String? note}) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
    child: pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(s, style: t(12.5, font: extra)),
        if (note != null) ...[
          pw.Spacer(),
          pw.Text(note, style: t(8.5, color: muted)),
        ],
      ],
    ),
  );

  pw.Widget card(pw.Widget child, {PdfColor? color, PdfColor? border}) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color ?? PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: border ?? line, width: 0.8),
        ),
        child: child,
      );

  pw.Widget pill(String s, {PdfColor? bg, PdfColor? fg}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: pw.BoxDecoration(
      color: bg ?? dark,
      borderRadius: pw.BorderRadius.circular(20),
    ),
    child: pw.Text(
      s,
      style: t(8.5, font: bold, color: fg ?? PdfColors.white),
    ),
  );

  /// بطاقات أرقام.
  pw.Widget kpis(List<(String, String)> items) => pw.Row(
    children: [
      for (final (value, label) in items)
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.all(3),
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: line, width: 0.8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  value,
                  style: t(17, font: extra, color: primary),
                ),
                pw.Text(label, style: t(8, color: muted)),
              ],
            ),
          ),
        ),
    ],
  );

  /// سطور (عنوان: قيمة) داخل كرت.
  pw.Widget facts(
    String title,
    List<(String, String)> rows, {
    pw.Widget? leading,
  }) => card(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            if (leading != null) ...[leading, pw.SizedBox(width: 8)],
            pw.Text(
              title,
              style: t(10, font: extra, color: primary),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        for (final (k, v) in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 62,
                  child: pw.Text(k, style: t(8.5, color: muted)),
                ),
                pw.Expanded(
                  child: pw.Text(
                    v.isEmpty ? '—' : v,
                    style: t(9.5, font: bold),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  /// جدول بعناوين ملوّنة وحواف ناعمة.
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
      color: header ? primary : (shade ? soft : PdfColors.white),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            pw.Expanded(
              flex: f[i],
              child: pw.Text(
                cells[i],
                style: header
                    ? t(8.5, font: bold, color: PdfColors.white)
                    : t(8.5),
              ),
            ),
        ],
      ),
    );
    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.Column(
        children: [
          row(head, header: true),
          for (var i = 0; i < rows.length; i++) row(rows[i], shade: i.isOdd),
        ],
      ),
    );
  }

  /// أشرطة نسبية.
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

  pw.Widget note(String title, String body, {PdfColor? color}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: pw.BoxDecoration(
      color: soft,
      border: pw.Border(right: pw.BorderSide(color: color ?? accent, width: 3)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: t(10, font: extra, color: color ?? primary),
        ),
        pw.SizedBox(height: 4),
        pw.Text(body, style: t(10, height: 3)),
      ],
    ),
  );

  pw.Widget avatar(Doctor? d, double size) {
    final photo = d?.photo;
    if (photo != null && File(photo).existsSync()) {
      return pw.ClipOval(
        child: pw.Image(
          pw.MemoryImage(File(photo).readAsBytesSync()),
          width: size,
          height: size,
          fit: pw.BoxFit.cover,
        ),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(color: primary, shape: pw.BoxShape.circle),
      child: pw.Text(
        d?.initial ?? '؟',
        style: t(size * 0.45, font: extra, color: PdfColors.white),
      ),
    );
  }

  /// الخط الزمني للزيارات (سطور منفصلة حتى تتوزع على أكثر من صفحة).
  List<pw.Widget> timeline(CaseRecord c) {
    final items = <(int, String, bool)>[
      (c.created, 'بداية ${b.teethChart ? 'الحالة' : 'الجلسات'}', false),
      for (final v in c.visits)
        (
          v.date,
          v.note.isEmpty ? (b.teethChart ? 'زيارة' : 'جلسة') : v.note,
          false,
        ),
      if (c.completed != null) (c.completed!, 'اكتمال الحالة', false),
      if (c.nextVisit != null && c.status == CaseStatus.active)
        (c.nextVisit!, '${b.f('المراجعة', 'الجلسة')} القادمة', true),
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    return [
      for (final (i, (date, label, future)) in items.indexed)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 16,
              child: pw.Column(
                children: [
                  pw.Container(
                    width: 11,
                    height: 11,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: future ? PdfColors.white : primary,
                      border: pw.Border.all(color: primary, width: 1.5),
                    ),
                  ),
                  if (i < items.length - 1)
                    pw.Container(width: 1.5, height: 24, color: line),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                arDate(date),
                style: t(9, font: bold, color: future ? primary : text),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                label,
                style: t(9, color: future ? primary : text),
              ),
            ),
          ],
        ),
    ];
  }
}

/// عنوان ومحتواه ما ينفصلون على صفحتين.
pw.Widget _keep({required List<pw.Widget> children}) => pw.Inseparable(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: children,
  ),
);

Future<Uint8List?> _composite(CaseRecord c, Brand b) async {
  final img = await renderReportComposite(c, b);
  if (img == null) return null;
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List?> _chart(CaseRecord c, Brand b) async {
  if (b.teethChart) {
    if (c.teeth.isEmpty) return null;
    return paintToPng(
      ToothChartPainter(
        selected: c.teeth.toSet(),
        primary: c.teeth.any(isPrimaryTooth),
        brand: b,
        fontScale: 1.1,
      ),
      const Size(600, 600 * teethAspect),
    );
  }
  if (c.areas.isEmpty) return null;
  return paintToPng(
    FaceMapPainter(
      selected: c.areas.toSet(),
      doses: c.doses,
      brand: b,
      showDoses: true,
    ),
    const Size(560, 700),
  );
}

String _patientLine(Patient p, Brand b) => [
  if (p.age != null) '${ar(p.age!)} سنة',
  if (p.gender != null && !b.feminine) p.gender!.label,
].join(' · ');

/// محتوى الحالة (مشترك بين تقرير الحالة وملف المراجع).
Future<List<pw.Widget>> _caseBody(
  _Kit k,
  Patient p,
  CaseRecord c, {
  bool full = true,
}) async {
  final b = k.b;
  final doctor = Store.instance.doctor(c.doctorId);
  final photo = await _composite(c, b);
  final chart = await _chart(c, b);
  final facts = CaseFacts.of(c);
  final alerts = caseAlerts(b, c);
  final done = c.status == CaseStatus.done;
  return [
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(c.title, style: k.t(18, font: k.extra)),
        ),
        k.pill(
          c.status.label,
          bg: done ? const PdfColor.fromInt(0xFFE3F1E6) : k.accent.shade(0.15),
          fg: done ? const PdfColor.fromInt(0xFF2E6B3B) : k.deep,
        ),
      ],
    ),
    pw.SizedBox(height: 8),
    k.note('الملخص', caseSummary(b, p, c, doctor)),
    pw.SizedBox(height: 8),
    k.kpis([
      (ar(facts.days), facts.done ? 'يوم للإكمال' : 'يوم من البداية'),
      (ar(facts.visits), b.teethChart ? 'زيارة' : 'جلسة'),
      (
        ar(b.teethChart ? c.teeth.length : c.areas.length),
        b.teethChart ? 'سن معالج' : 'منطقة معالجة',
      ),
      (
        facts.nextVisit == null || done
            ? '—'
            : (facts.daysToNext! >= 0 ? ar(facts.daysToNext!) : 'فات'),
        facts.nextVisit == null || done
            ? 'ماكو موعد قادم'
            : 'يوم للموعد القادم',
      ),
    ]),
    if (full) ...[
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: k.facts(b.f('المراجع', 'المراجعة'), [
              ('الاسم', p.name),
              ('العمر', _patientLine(p, b)),
              ('الهاتف', p.phone),
              ('أول زيارة', arDate(p.created)),
            ]),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: k.facts('الطبيب المعالج', [
              ('الاسم', doctor?.name ?? ''),
              ('الاختصاص', doctor?.specialty ?? ''),
              ('الهاتف', doctor?.phone ?? ''),
            ], leading: k.avatar(doctor, 26)),
          ),
        ],
      ),
    ],
    if (photo != null)
      // العنوان ويه محتواه بنفس الصفحة.
      _keep(
        children: [
          k.section(
            'قبل وبعد',
            note: [
              if (c.before?.taken != null) 'قبل: ${arDate(c.before!.taken!)}',
              if (c.after?.taken != null) 'بعد: ${arDate(c.after!.taken!)}',
            ].join('  ·  '),
          ),
          pw.Center(
            child: pw.ClipRRect(
              horizontalRadius: 12,
              verticalRadius: 12,
              child: pw.Image(pw.MemoryImage(photo), height: full ? 300 : 190),
            ),
          ),
        ],
      ),
    if (chart != null)
      _keep(
        children: [
          k.section(b.teethChart ? 'خريطة الأسنان' : 'خريطة الأجزاء المعالجة'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: b.teethChart
                    ? k.table(
                        ['الأسنان المعالجة'],
                        [
                          for (final t in c.teeth) [toothName(t)],
                        ],
                      )
                    : k.table(
                        ['المنطقة', 'الكمية'],
                        [
                          for (final id in c.areas)
                            [areaLabel(id), c.doses[id] ?? '—'],
                        ],
                        flex: [3, 2],
                      ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                flex: 4,
                child: k.card(
                  pw.Image(pw.MemoryImage(chart)),
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    if (full) ...[
      // العنوان ويه أول سطر، والباقي يتوزع على الصفحات.
      _keep(
        children: [
          k.section(
            b.teethChart ? 'الخط الزمني للزيارات' : 'الخط الزمني للجلسات',
          ),
          k.timeline(c).first,
        ],
      ),
      ...k.timeline(c).skip(1),
    ],
    if (c.note.isNotEmpty) ...[
      pw.SizedBox(height: 12),
      k.note('ملاحظات الطبيب', c.note),
    ],
    if (full && alerts.isNotEmpty) ...[
      pw.SizedBox(height: 10),
      k.note(
        'للمتابعة',
        alerts.map((a) => '• $a').join('\n'),
        color: const PdfColor.fromInt(0xFFB26A00),
      ),
    ],
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
  final body = await _caseBody(k, p, c);
  final doc = k.doc('تقرير حالة - ${p.name}');
  doc.addPage(
    k.page(
      title: 'تقرير حالة',
      subtitle: '${p.name} · ${c.title}',
      body: () => [
        ...body,
        pw.SizedBox(height: 28),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('توقيع الطبيب', style: k.t(9, color: k.muted)),
                pw.SizedBox(height: 18),
                pw.Container(width: 150, height: 0.8, color: k.line),
              ],
            ),
            pw.Container(
              width: 70,
              height: 70,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: k.line, width: 0.8),
              ),
              child: pw.Text('الختم', style: k.t(9, color: k.muted)),
            ),
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
  final cases = [
    for (final c in p.cases) await _caseBody(k, p, c, full: false),
  ];
  final visits = p.cases.fold(0, (n, c) => n + c.visits.length);
  final doc = k.doc('ملف ${p.name}');
  doc.addPage(
    k.page(
      title: 'ملف ${b.f('المراجع', 'المراجعة')}',
      subtitle: p.name,
      body: () => [
        k.kpis([
          (ar(p.cases.length), 'حالة'),
          (
            ar(p.cases.where((c) => c.status == CaseStatus.active).length),
            'قيد العلاج',
          ),
          (
            ar(p.cases.where((c) => c.status == CaseStatus.done).length),
            'مكتملة',
          ),
          (ar(visits), b.teethChart ? 'زيارة' : 'جلسة'),
        ]),
        pw.SizedBox(height: 8),
        k.facts('البيانات', [
          ('الاسم', p.name),
          ('العمر', _patientLine(p, b)),
          ('الهاتف', p.phone),
          ('أول زيارة', arDate(p.created)),
        ]),
        if (p.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          k.note('ملاحظات عامة', p.notes),
        ],
        for (final body in cases) ...[
          pw.SizedBox(height: 14),
          pw.Divider(color: k.line),
          ...body,
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
      title: 'تقرير الطبيب',
      subtitle: d.name,
      body: () => [
        pw.Row(
          children: [
            k.avatar(d, 54),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(d.name, style: k.t(16, font: k.extra)),
                  pw.Text(d.specialty, style: k.t(10, color: k.muted)),
                  if (d.services.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final x in d.services) k.pill(x, bg: k.primary),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (d.bio.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          k.note('نبذة', d.bio),
        ],
        k.section('بالأرقام'),
        k.kpis([
          (ar(s.total), 'حالة'),
          (ar(s.patients), b.patients),
          (ar(s.done), 'مكتملة'),
          (
            s.avgDays == null ? '—' : ar(s.avgDays!.round()),
            'يوم متوسط العلاج',
          ),
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
      title: 'التقرير الشامل',
      subtitle: '${b.name} · $scope',
      body: () => [
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
