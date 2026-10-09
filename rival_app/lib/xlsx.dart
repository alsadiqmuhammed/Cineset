import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// قراءة وكتابة ملفات Excel (xlsx) بدون مكتبات ثقيلة: الملف zip بداخله XML.
/// القراءة تفهم النصوص المشتركة والمضمّنة والأرقام والتواريخ.

/// ورقة: اسمها وصفوفها (كل خلية نص؛ الفارغة '').
class Sheet {
  final String name;
  final List<List<String>> rows;
  const Sheet(this.name, this.rows);
}

const _main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _rel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

/// يقرا كل أوراق الملف بالترتيب.
List<Sheet> readXlsx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  String? text(String path) {
    final f = zip.findFile(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final shared = <String>[];
  final ss = text('xl/sharedStrings.xml');
  if (ss != null) {
    for (final si in XmlDocument.parse(ss).findAllElements('si')) {
      shared.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  // أنماط التواريخ: الخلية رقم بس تنعرض كتاريخ.
  final dateStyles = <int>{};
  final st = text('xl/styles.xml');
  if (st != null) {
    final doc = XmlDocument.parse(st);
    final custom = <int, String>{
      for (final f in doc.findAllElements('numFmt'))
        int.parse(f.getAttribute('numFmtId') ?? '0'):
            f.getAttribute('formatCode') ?? '',
    };
    final xfs = doc.findAllElements('cellXfs').firstOrNull;
    if (xfs != null) {
      var i = 0;
      for (final xf in xfs.findElements('xf')) {
        final id = int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0;
        final code = (custom[id] ?? '').toLowerCase();
        final builtin = (id >= 14 && id <= 22) || (id >= 45 && id <= 47);
        final looks =
            code.contains('y') ||
            (code.contains('d') && code.contains('m') && !code.contains('0'));
        if (builtin || looks) dateStyles.add(i);
        i++;
      }
    }
  }

  final wb = XmlDocument.parse(text('xl/workbook.xml') ?? '<workbook/>');
  final rels = <String, String>{};
  final relsXml = text('xl/_rels/workbook.xml.rels');
  if (relsXml != null) {
    for (final r in XmlDocument.parse(
      relsXml,
    ).findAllElements('Relationship')) {
      rels[r.getAttribute('Id') ?? ''] = r.getAttribute('Target') ?? '';
    }
  }
  final out = <Sheet>[];
  var n = 0;
  for (final s in wb.findAllElements('sheet')) {
    n++;
    final rid = s.getAttribute('id', namespaceUri: _rel) ?? s.getAttribute('r:id');
    var target = rels[rid] ?? 'worksheets/sheet$n.xml';
    if (target.startsWith('/')) {
      target = target.substring(1);
    } else if (!target.startsWith('xl/')) {
      target = 'xl/$target';
    }
    final xml = text(target);
    if (xml == null) continue;
    out.add(
      Sheet(
        s.getAttribute('name') ?? 'Sheet$n',
        _rows(xml, shared, dateStyles),
      ),
    );
  }
  return out;
}

List<List<String>> _rows(String xml, List<String> shared, Set<int> dates) {
  final rows = <List<String>>[];
  for (final row in XmlDocument.parse(xml).findAllElements('row')) {
    final r = int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1;
    while (rows.length < r - 1) {
      rows.add([]);
    }
    final cells = <String>[];
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r');
      final col = ref == null ? cells.length : _col(ref);
      while (cells.length < col) {
        cells.add('');
      }
      final t = c.getAttribute('t');
      final v = c.findElements('v').firstOrNull?.innerText ?? '';
      String value;
      switch (t) {
        case 's':
          final i = int.tryParse(v);
          value = i != null && i < shared.length ? shared[i] : '';
        case 'inlineStr':
          value = c.findAllElements('t').map((e) => e.innerText).join();
        case 'b':
          value = v == '1' ? 'TRUE' : 'FALSE';
        case 'str' || 'e':
          value = v;
        default:
          final style = int.tryParse(c.getAttribute('s') ?? '');
          final num = double.tryParse(v);
          if (num != null && style != null && dates.contains(style)) {
            value = _excelDate(num);
          } else if (num != null &&
              num == num.roundToDouble() &&
              !v.contains('E')) {
            value = num.toInt().toString();
          } else {
            value = v;
          }
      }
      cells.add(value);
    }
    rows.add(cells);
  }
  return rows;
}

int _col(String ref) {
  var n = 0;
  for (final ch in ref.codeUnits) {
    if (ch < 65 || ch > 90) break;
    n = n * 26 + (ch - 64);
  }
  return n - 1;
}

String _excelDate(double serial) {
  final d = DateTime.utc(
    1899,
    12,
    30,
  ).add(Duration(milliseconds: (serial * 86400000).round()));
  String two(int x) => x.toString().padLeft(2, '0');
  final day = '${d.year}-${two(d.month)}-${two(d.day)}';
  if (serial == serial.floorToDouble()) return day;
  return '$day ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String _colName(int i) {
  var s = '';
  var n = i + 1;
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // محارف تحكم ما يقبلها XML.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

/// يكتب ملف Excel: الأوراق من اليمين لليسار، الصف الأول عنوان عريض ومثبّت،
/// وعرض كل عمود حسب محتواه.
Uint8List writeXlsx(List<Sheet> sheets) {
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>''',
  );
  add(
    '_rels/.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''',
  );
  add(
    'xl/workbook.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="$_main" xmlns:r="$_rel"><bookViews><workbookView/></bookViews><sheets>${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>''',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>''',
  );
  add(
    'xl/styles.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="$_main"><fonts count="2"><font><sz val="11"/><name val="Arial"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Arial"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFA82E12"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="2"><xf fontId="0" fillId="0" borderId="0"><alignment readingOrder="2"/></xf><xf fontId="1" fillId="2" borderId="0" applyFont="1" applyFill="1"><alignment horizontal="center" vertical="center" readingOrder="2"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>''',
  );

  for (var i = 0; i < sheets.length; i++) {
    final rows = sheets[i].rows;
    final cols = rows.fold(0, (m, r) => r.length > m ? r.length : m);
    final widths = List<int>.filled(cols, 8);
    for (final r in rows) {
      for (var c = 0; c < r.length; c++) {
        final w =
            r[c].split('\n').fold(0, (m, l) => l.length > m ? l.length : m) + 2;
        if (w > widths[c]) widths[c] = w > 48 ? 48 : w;
      }
    }
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="$_main"><sheetViews><sheetView rightToLeft="1" workbookViewId="0">',
      )
      ..write(
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>',
      )
      ..write(
        '</sheetView></sheetViews><sheetFormatPr defaultRowHeight="16"/>',
      );
    if (cols > 0) {
      b.write('<cols>');
      for (var c = 0; c < cols; c++) {
        b.write(
          '<col min="${c + 1}" max="${c + 1}" width="${widths[c]}" customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v.isEmpty) continue;
        final style = r == 0 ? ' s="1"' : '';
        b.write(
          '<c r="${_colName(c)}${r + 1}" t="inlineStr"$style><is><t xml:space="preserve">${_esc(v)}</t></is></c>',
        );
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    add('xl/worksheets/sheet${i + 1}.xml', b.toString());
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
