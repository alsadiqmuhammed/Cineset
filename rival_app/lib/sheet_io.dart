import 'dart:typed_data';

import 'brand.dart';
import 'models.dart';
import 'store.dart';
import 'xlsx.dart';

/// تصدير واستيراد سجل المراجعين كملف Excel.
/// كل صف = حالة (نوع علاج بزيارة ومبلغ)، والمراجع يتجمع بالمعرّف أو بالهاتف والاسم.
/// الأعمدة نفس جدول العيادة القديم، حتى الملف يطلع ويرجع بدون ما يضيع شي.

const kSheetColumns = [
  'م',
  'اسم المراجع',
  'رقم الهاتف',
  'رقم آخر',
  'معرّف (ID)',
  'نوع الحالة',
  'تاريخ الزيارة',
  'مديون',
  'المبلغ المتبقي',
  'المبلغ المتفق عليه',
  'حالة العلاج',
  'أمراض مزمنة',
  'حساسية',
  'أدوية',
  'الجنس',
  'الميلاد',
  'العنوان',
  'المهنة',
  'الطبيب المعالج',
  'رقم الملف',
  'الايميل',
  'ملاحظات المراجع',
  'ملاحظات العمل',
  'الحساب',
  'آخر تعديل',
  'الأسنان',
  'معرّف الحالة',
];

enum SheetField {
  name,
  phone,
  phone2,
  id,
  type,
  date,
  remaining,
  price,
  status,
  conditions,
  allergies,
  meds,
  gender,
  birth,
  address,
  job,
  doctor,
  fileNo,
  email,
  patientNotes,
  workNotes,
  account,
  updated,
  teeth,
  caseId,
}

/// أسماء الأعمدة المقبولة لكل حقل (بعد التبسيط).
final _aliases = <SheetField, List<String>>{
  SheetField.name: ['اسم المراجع', 'الاسم', 'اسم المريض', 'المراجع', 'name'],
  SheetField.phone: [
    'رقم الهاتف',
    'الهاتف',
    'الموبايل',
    'رقم الموبايل',
    'phone',
  ],
  SheetField.phone2: ['رقم آخر', 'رقم اخر', 'هاتف ثاني', 'رقم ثاني'],
  SheetField.id: ['معرف (id)', 'معرف', 'id', 'رقم المراجع'],
  SheetField.type: ['نوع الحالة', 'العلاج', 'نوع العلاج', 'الحالة'],
  SheetField.date: ['تاريخ الزيارة', 'التاريخ', 'تاريخ', 'date'],
  SheetField.remaining: ['المبلغ المتبقي', 'المتبقي', 'الباقي'],
  SheetField.price: ['المبلغ المتفق عليه', 'المبلغ', 'الكلفة', 'السعر'],
  SheetField.status: ['حالة العلاج', 'الوضع'],
  SheetField.conditions: ['امراض مزمنة', 'الامراض المزمنة', 'امراض'],
  SheetField.allergies: ['حساسية', 'الحساسية'],
  SheetField.meds: ['ادوية', 'الادوية'],
  SheetField.gender: ['الجنس', 'gender'],
  SheetField.birth: ['الميلاد', 'تاريخ الميلاد', 'المواليد'],
  SheetField.address: ['العنوان', 'السكن'],
  SheetField.job: ['المهنة', 'العمل'],
  SheetField.doctor: ['الطبيب المعالج', 'الطبيب', 'الطبيبة'],
  SheetField.fileNo: ['رقم الملف'],
  SheetField.email: ['الايميل', 'البريد', 'email'],
  SheetField.patientNotes: ['ملاحظات المراجع'],
  SheetField.workNotes: ['ملاحظات العمل', 'ملاحظات', 'ملاحظات الحالة'],
  SheetField.account: ['الحساب'],
  SheetField.updated: ['اخر تعديل'],
  SheetField.teeth: ['الاسنان'],
  SheetField.caseId: ['معرف الحالة'],
};

String _norm(String s) =>
    searchKey(s).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// صف من الملف بعد التنظيف.
class SheetRow {
  final int line;
  final Map<SheetField, String> v;
  SheetRow(this.line, this.v);
  String operator [](SheetField c) => v[c] ?? '';
}

/// مراجع من الملف ويا حالاته.
class ImportPatient {
  final String key;
  final List<SheetRow> rows = [];
  ImportPatient(this.key);
  SheetRow get first => rows.first;
}

/// نتيجة قراءة الملف قبل الحفظ.
class ImportPlan {
  final List<ImportPatient> patients;

  /// أسماء الأطباء بالملف (عمود الطبيب، وإذا فارغ عمود الحساب) وكم حالة لكل واحد.
  final Map<String, int> doctors;
  final List<String> warnings;
  final int rows;
  const ImportPlan(this.patients, this.doctors, this.warnings, this.rows);

  int get cases => patients.fold(0, (s, p) => s + p.rows.length);
}

/// يقرا ملف Excel ويجهز خطة الاستيراد. يرمي FormatException إذا ما لگه جدول مراجعين.
ImportPlan readPatientsSheet(Uint8List bytes) {
  final sheets = readXlsx(bytes);
  for (final sheet in sheets) {
    final rows = sheet.rows;
    for (var h = 0; h < rows.length && h < 10; h++) {
      final cols = <SheetField, int>{};
      for (var i = 0; i < rows[h].length; i++) {
        final name = _norm(rows[h][i]);
        if (name.isEmpty) continue;
        for (final e in _aliases.entries) {
          if (cols.containsKey(e.key)) continue;
          if (e.value.any((a) => _norm(a) == name)) {
            cols[e.key] = i;
            break;
          }
        }
      }
      if (!cols.containsKey(SheetField.name)) continue;
      return _plan(rows, h, cols);
    }
  }
  throw const FormatException('ما لگيت عمود "اسم المراجع" بالملف.');
}

ImportPlan _plan(
  List<List<String>> rows,
  int header,
  Map<SheetField, int> cols,
) {
  final groups = <String, ImportPatient>{};
  final doctors = <String, int>{};
  final warnings = <String>[];
  var count = 0;
  for (var r = header + 1; r < rows.length; r++) {
    final row = rows[r];
    final v = <SheetField, String>{
      for (final e in cols.entries)
        if (e.value < row.length) e.key: row[e.value].trim(),
    };
    final name = (v[SheetField.name] ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) continue;
    v[SheetField.name] = name;
    count++;
    final sr = SheetRow(r + 1, v);
    final id = latinDigits(v[SheetField.id] ?? '');
    final phone = latinDigits(v[SheetField.phone] ?? '')
        .replaceAll(RegExp(r'\D'), '');
    final key = id.isNotEmpty
        ? 'id:$id'
        : phone.isNotEmpty
        ? 'ph:$phone|${searchKey(name)}'
        : 'nm:${searchKey(name)}';
    (groups[key] ??= ImportPatient(key)).rows.add(sr);
    final doc = doctorOf(sr);
    if (doc.isNotEmpty) doctors[doc] = (doctors[doc] ?? 0) + 1;
    if ((v[SheetField.date] ?? '').isNotEmpty &&
        parseSheetDate(v[SheetField.date]!) == null) {
      warnings.add(
        'سطر ${r + 1}: تاريخ الزيارة "${v[SheetField.date]}" مو مفهوم، انحط تاريخ اليوم.',
      );
    }
  }
  return ImportPlan(groups.values.toList(), doctors, warnings, count);
}

String doctorOf(SheetRow r) => r[SheetField.doctor].isNotEmpty
    ? r[SheetField.doctor]
    : r[SheetField.account];

/// تاريخ من الملف: 2026-10-09 أو 2026/10/09 أو 09/10/2026 (ويا وقت اختياري).
DateTime? parseSheetDate(String raw) {
  final s = latinDigits(raw).trim();
  var m = RegExp(
    r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(s);
  if (m != null) {
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(
      y,
      mo,
      d,
      int.tryParse(m[4] ?? '') ?? 0,
      int.tryParse(m[5] ?? '') ?? 0,
      int.tryParse(m[6] ?? '') ?? 0,
    );
  }
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})').firstMatch(s);
  if (m != null) {
    final d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }
  return null;
}

/// ملاحظات بالنظام القديم مخزونة بترميز الروابط (%D8%A7...) و"|" بين الأسطر.
String decodeNote(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  if (RegExp(r'%[0-9A-Fa-f]{2}').hasMatch(s)) {
    try {
      s = Uri.decodeComponent(s.replaceAll('+', '%2B'));
    } catch (_) {}
  }
  return s
      .split('|')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join('\n')
      .trim();
}

/// أرقام الأسنان (FDI) من ملاحظات مثل "LR6+7" أو "UL5" أو "UR 1".
List<int> teethFromText(String text) {
  const q = {'UR': 1, 'UL': 2, 'LL': 3, 'LR': 4};
  final out = <int>{};
  for (final m in RegExp(
    r'\b(UR|UL|LL|LR)\s*([1-8](?:\s*[+,&و]\s*[1-8])*)',
    caseSensitive: false,
  ).allMatches(text)) {
    final quad = q[m[1]!.toUpperCase()]!;
    for (final d in RegExp(r'[1-8]').allMatches(m[2]!)) {
      out.add(quad * 10 + int.parse(d[0]!));
    }
  }
  // أرقام FDI صريحة بعمود الأسنان (11, 26 ...).
  return out.toList()..sort();
}

List<int> _teethColumn(String s) => [
  for (final m in RegExp(
    r'\b([1-4][1-8]|[5-8][1-5])\b',
  ).allMatches(latinDigits(s)))
    int.parse(m[1]!),
];

Gender? _gender(String s) {
  final n = _norm(s);
  if (n.isEmpty) return null;
  if (n.startsWith('ان') || n == 'f' || n == 'female' || n.contains('مونث')) {
    return Gender.female;
  }
  if (n.startsWith('ذكر') || n == 'm' || n == 'male') return Gender.male;
  return null;
}

bool _done(String s) {
  final n = _norm(s);
  return n.startsWith('منته') || n.startsWith('مكتمل') || n == 'done';
}

String _caseKey(String patientKey, SheetRow r, int dup) =>
    'x${_hash('$patientKey|${r[SheetField.date]}|${r[SheetField.type]}|${r[SheetField.price]}|${r[SheetField.remaining]}|$dup')}';

String _hash(String s) {
  // FNV-1a ثابت بين الأجهزة (حتى الاستيراد مرتين ما يكرر الحالات).
  var h = 0xcbf29ce484222325;
  for (final c in s.codeUnits) {
    h ^= c;
    h = h * 0x100000001b3;
  }
  return h.toUnsigned(64).toRadixString(36);
}

/// نتيجة الحفظ.
class ImportResult {
  int newPatients = 0, updatedPatients = 0, newCases = 0, skipped = 0;
}

/// يحفظ الخطة بالأرشيف. [doctorMap]: اسم الطبيب بالملف ← رقم ملف الطبيب بالتطبيق.
/// المراجع الموجود ما تنمسح بياناته؛ بس الحقول الفارغة تتعبى من الملف.
Future<ImportResult> applyImport(
  ImportPlan plan,
  Map<String, String?> doctorMap, {
  String? fallbackDoctor,
}) async {
  final store = Store.instance;
  final res = ImportResult();
  final now = DateTime.now();
  String phoneKey(String p) =>
      latinDigits(p)
          .replaceAll(RegExp(r'\D'), '')
          .replaceFirst(RegExp(r'^(00964|964|0)'), '');

  for (final ip in plan.patients) {
    final f = ip.first;
    final extId = latinDigits(f[SheetField.id]);
    final phone = latinDigits(f[SheetField.phone]);
    Patient? p;
    for (final x in store.patients) {
      if (extId.isNotEmpty && (x.externalId == extId || x.id == extId)) {
        p = x;
        break;
      }
    }
    if (p == null && phone.isNotEmpty) {
      for (final x in store.patients) {
        if (phoneKey(x.phone) == phoneKey(phone) &&
            searchKey(x.name) == searchKey(f[SheetField.name])) {
          p = x;
          break;
        }
      }
    }
    final dates = [for (final r in ip.rows) ?parseSheetDate(r[SheetField.date])]
      ..sort();
    final birth = parseSheetDate(f[SheetField.birth]);
    final isNew = p == null;
    p ??= Patient(
      id: extId.isNotEmpty ? 'x$extId' : 'x${_hash(ip.key)}',
      name: f[SheetField.name],
      phone: phone,
      created: (dates.isEmpty ? now : dates.first).millisecondsSinceEpoch,
      createdBy: store.myDoctorId,
    );
    void fill(String Function() get, void Function(String) set, String value) {
      if (get().trim().isEmpty && value.trim().isNotEmpty) set(value.trim());
    }

    // الحقول من أول صف فيه قيمة (المراجع ممكن تتكرر بياناته بكل صف).
    String firstOf(SheetField c) {
      for (final r in ip.rows) {
        if (r[c].isNotEmpty) return r[c];
      }
      return '';
    }

    final pp = p;
    fill(() => pp.phone, (v) => pp.phone = v, phone);
    fill(
      () => pp.phone2,
      (v) => pp.phone2 = v,
      latinDigits(firstOf(SheetField.phone2)),
    );
    fill(() => pp.externalId, (v) => pp.externalId = v, extId);
    fill(() => pp.address, (v) => pp.address = v, firstOf(SheetField.address));
    fill(() => pp.job, (v) => pp.job = v, firstOf(SheetField.job));
    fill(() => pp.email, (v) => pp.email = v, firstOf(SheetField.email));
    fill(() => pp.fileNo, (v) => pp.fileNo = v, firstOf(SheetField.fileNo));
    fill(
      () => pp.conditions,
      (v) => pp.conditions = v,
      firstOf(SheetField.conditions),
    );
    fill(
      () => pp.allergies,
      (v) => pp.allergies = v,
      firstOf(SheetField.allergies),
    );
    fill(
      () => pp.medications,
      (v) => pp.medications = v,
      firstOf(SheetField.meds),
    );
    fill(
      () => pp.notes,
      (v) => pp.notes = v,
      decodeNote(firstOf(SheetField.patientNotes)),
    );
    pp.gender ??= _gender(firstOf(SheetField.gender));
    if (pp.birthDate == null && birth != null) {
      pp.birthDate = DateTime(
        birth.year,
        birth.month,
        birth.day,
      ).millisecondsSinceEpoch;
      pp.birthYear = birth.year;
    }

    final seen = <String, int>{};
    var added = false;
    for (final r in ip.rows) {
      final sig =
          '${r[SheetField.date]}|${r[SheetField.type]}|${r[SheetField.price]}|${r[SheetField.remaining]}';
      final dup = seen[sig] = (seen[sig] ?? -1) + 1;
      final caseId = r[SheetField.caseId].isNotEmpty
          ? r[SheetField.caseId]
          : _caseKey(ip.key, r, dup);
      if (pp.cases.any((c) => c.id == caseId)) {
        res.skipped++;
        continue;
      }
      final day = parseSheetDate(r[SheetField.date]) ?? now;
      final created = DateTime(
        day.year,
        day.month,
        day.day,
        12,
      ).millisecondsSinceEpoch;
      final price = parseAmount(r[SheetField.price]);
      final remaining = parseAmount(r[SheetField.remaining]) ?? 0;
      final total = price ?? (remaining > 0 ? remaining : null);
      final paid = total == null ? 0 : total - remaining;
      final note = decodeNote(r[SheetField.workNotes]);
      final title = r[SheetField.type].isEmpty
          ? 'غير محدد'
          : r[SheetField.type];
      final done = _done(r[SheetField.status]);
      final doctor =
          store.myDoctorId ?? doctorMap[doctorOf(r)] ?? fallbackDoctor;
      final teeth = {
        ...teethFromText(note),
        ..._teethColumn(r[SheetField.teeth]),
      }.toList()..sort();
      pp.cases.add(
        CaseRecord(
          id: caseId,
          title: title,
          note: note,
          created: created,
          doctorId: doctor,
          status: done ? CaseStatus.done : CaseStatus.active,
          completed: done ? created : null,
          teeth: store.brand.teethChart ? teeth : null,
          price: total,
          visits: [Visit(id: '${caseId}v', date: created, note: title)],
          payments: [
            if (paid > 0)
              Payment(
                id: '${caseId}p',
                date: created,
                amount: paid,
                note: 'مدفوع (من الجدول)',
              ),
          ],
        ),
      );
      res.newCases++;
      added = true;
    }
    pp.cases.sort((a, b) => b.created.compareTo(a.created));
    if (isNew) {
      store.patients.add(pp);
      res.newPatients++;
    } else if (added) {
      res.updatedPatients++;
    }
  }
  store.patients.sort((a, b) {
    final ca = a.cases.isEmpty ? a.created : a.cases.first.created;
    final cb = b.cases.isEmpty ? b.created : b.cases.first.created;
    return cb.compareTo(ca);
  });
  await store.saveAll();
  return res;
}

/// يصدّر كل المراجعين والحالات بنفس أعمدة الاستيراد، ويا ورقة ملخص.
Uint8List exportPatientsSheet() {
  final store = Store.instance;
  final docs = {for (final d in store.doctors) d.id: d.name};
  String amount(int? v) {
    if (v == null) return '';
    final s = v.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$b';
  }

  String day(int? ms) {
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String stamp(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int x) => x.toString().padLeft(2, '0');
    return '${day(ms)} ${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
  }

  final rows = <List<String>>[kSheetColumns];
  var n = 0;
  var debtors = 0, active = 0, medical = 0, totalDue = 0;
  final types = <String, int>{};
  int? first, last;
  for (final p in store.patients) {
    List<String> base(CaseRecord? c) {
      final due = c?.due ?? 0;
      final touched = c == null
          ? p.created
          : [
              c.created,
              for (final v in c.visits) v.date,
              for (final pay in c.payments) pay.date,
            ].reduce((a, b) => a > b ? a : b);
      return [
        '${++n}',
        p.name,
        p.phone,
        p.phone2,
        p.externalId.isNotEmpty ? p.externalId : p.id,
        c?.title ?? '',
        day(c?.created),
        due > 0 ? 'نعم' : '',
        c == null ? '' : amount(due > 0 ? due : 0),
        amount(c?.price),
        c == null ? '' : (c.status == CaseStatus.done ? 'منتهية' : 'مستمرة'),
        p.conditions,
        p.allergies,
        p.medications,
        p.gender == Gender.female
            ? 'انثى'
            : p.gender == Gender.male
            ? 'ذكر'
            : '',
        p.birthDate != null
            ? day(p.birthDate)
            : (p.birthYear?.toString() ?? ''),
        p.address,
        p.job,
        docs[c?.doctorId] ?? '',
        p.fileNo,
        p.email,
        p.notes,
        c?.note ?? '',
        store.account ?? '',
        stamp(touched),
        c == null ? '' : c.teeth.join(' '),
        c?.id ?? '',
      ];
    }

    if (p.cases.isEmpty) {
      rows.add(base(null));
      continue;
    }
    for (final c in p.cases) {
      rows.add(base(c));
      final due = c.due ?? 0;
      if (due > 0) {
        debtors++;
        totalDue += due;
      }
      if (c.status == CaseStatus.active) active++;
      if (p.conditions.trim().isNotEmpty) medical++;
      types[c.title] = (types[c.title] ?? 0) + 1;
      first = first == null || c.created < first ? c.created : first;
      last = last == null || c.created > last ? c.created : last;
    }
  }
  final caseRows = rows.length - 1;
  final summary = <List<String>>[
    ['ملخص قاعدة بيانات المراجعين — ${store.brand.name}', ''],
    ['', ''],
    ['إجمالي السجلات (حالات)', '$caseRows'],
    ['عدد المراجعين', '${store.patients.length}'],
    [
      'سجلات فيها رقم هاتف',
      '${rows.skip(1).where((r) => r[2].isNotEmpty).length}',
    ],
    if (first != null) ['الفترة', '${day(first)}  إلى  ${day(last)}'],
    ['حالات مدينة', '$debtors'],
    ['إجمالي المبالغ المتبقية (IQD)', amount(totalDue)],
    ['حالات فيها أمراض مزمنة', '$medical'],
    ['حالات مستمرة', '$active'],
    ['', ''],
    ['توزيع أنواع الحالات', 'العدد'],
    for (final e
        in (types.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
      [e.key, '${e.value}'],
  ];
  return writeXlsx([Sheet('المراجعين', rows), Sheet('ملخص', summary)]);
}
