import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../brand.dart';
import '../download.dart';
import '../sheet_io.dart';
import '../store.dart';
import 'common.dart';
import 'design_controls.dart' show shareFile;

/// يصدّر المراجعين والحالات كملف Excel ويفتح المشاركة.
Future<void> exportExcel(BuildContext context) async {
  final store = Store.instance;
  if (store.patients.isEmpty) {
    toast(context, 'ماكو مراجعين للتصدير بعد.');
    return;
  }
  try {
    final bytes = exportPatientsSheet();
    final d = DateTime.now();
    final name =
        'ريڤال_${store.brand.section == Section.dental ? 'أسنان' : 'تجميل'}_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.xlsx';
    if (kIsWeb) {
      await downloadBytes(
        bytes,
        name,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      return;
    }
    final file = File('${store.exportsDir.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await shareFile(file.path);
  } catch (e) {
    if (context.mounted) toast(context, 'ما تم التصدير: $e');
  }
}

/// يختار ملف Excel ويفتح شاشة مراجعة الاستيراد.
Future<void> importExcel(BuildContext context) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (files.isEmpty || !context.mounted) return;
  final picked = files.first;
  ImportPlan plan;
  try {
    if (kIsWeb) {
      // بالمتصفح ماكو مسار ولا خيوط منفصلة: نقرا البايتات مباشرة.
      plan = readPatientsSheet(await picked.xFile.readAsBytes());
    } else {
      final path = picked.path;
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      plan = await Isolate.run(
        () => readPatientsSheet(Uint8List.fromList(bytes)),
      );
    }
  } on FormatException catch (e) {
    if (context.mounted) toast(context, e.message);
    return;
  } catch (e) {
    if (context.mounted) toast(context, 'الملف مو مفهوم: $e');
    return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ImportSheetScreen(plan: plan)),
  );
}

/// مراجعة قبل الاستيراد: الأرقام، ربط أسماء الأطباء بالملف بأطباء التطبيق، والتنبيهات.
class ImportSheetScreen extends StatefulWidget {
  final ImportPlan plan;
  const ImportSheetScreen({super.key, required this.plan});

  @override
  State<ImportSheetScreen> createState() => _ImportSheetScreenState();
}

class _ImportSheetScreenState extends State<ImportSheetScreen> {
  late final Map<String, String?> _map = {
    for (final name in widget.plan.doctors.keys) name: _guess(name),
  };
  bool _busy = false;

  /// تخمين الطبيب: نفس الاسم، أو أول كلمة من الاسم اللاتيني تشبه اسمه
  /// (Mustafa ← مصطفى)، وإلا ملفي.
  String? _guess(String name) {
    final store = Store.instance;
    final key = searchKey(name);
    for (final d in store.doctors) {
      final n = searchKey(d.name.replaceFirst(RegExp(r'^د\.?\s*'), ''));
      if (n.isNotEmpty && (key.contains(n) || n.contains(key))) return d.id;
    }
    const latin = {
      'mustafa': 'مصطفى',
      'mostafa': 'مصطفى',
      'shams': 'شمس',
      'ali': 'علي',
      'hanin': 'حنين',
      'haneen': 'حنين',
      'rabab': 'رباب',
      'duha': 'ضحى',
      'zahraa': 'زهراء',
      'noor': 'نور',
      'mohammed': 'محمد',
      'ahmed': 'احمد',
    };
    final low = name.toLowerCase();
    for (final e in latin.entries) {
      if (!low.contains(e.key)) continue;
      for (final d in store.doctors) {
        if (searchKey(d.name).contains(searchKey(e.value))) return d.id;
      }
    }
    return store.activeDoctor?.id;
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      final r = await applyImport(widget.plan, _map);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تم الاستيراد ✓'),
          content: Text(
            [
              '${ar(r.newPatients)} ${Store.instance.brand.patient} جديد',
              if (r.updatedPatients > 0)
                '${ar(r.updatedPatients)} انضافتله حالات',
              '${ar(r.newCases)} حالة',
              if (r.skipped > 0)
                '${ar(r.skipped)} حالة موجودة من قبل (ما تكررت)',
            ].join('\n'),
            style: const TextStyle(height: 1.8),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تمام'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'ما تم الاستيراد: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final store = Store.instance;
    final plan = widget.plan;
    var remaining = 0, active = 0, medical = 0;
    for (final p in plan.patients) {
      for (final r in p.rows) {
        remaining += parseAmount(r[SheetField.remaining]) ?? 0;
        final st = searchKey(r[SheetField.status]);
        if (!st.startsWith('منته') && !st.startsWith('مكتمل')) active++;
      }
      if (p.rows.any(
        (r) =>
            r[SheetField.conditions].isNotEmpty ||
            r[SheetField.allergies].isNotEmpty ||
            r[SheetField.meds].isNotEmpty,
      )) {
        medical++;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد من Excel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          BrandCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Big(ar(plan.patients.length), b.patients, b.primaryDeep),
                    _Big(ar(plan.cases), 'حالة', b.highlight),
                    _Big(ar(active), 'مستمرة', b.text),
                  ],
                ),
                const SizedBox(height: 14),
                _Line(
                  Icons.account_balance_wallet_outlined,
                  'المبالغ المتبقية: ${money(remaining)}',
                ),
                _Line(
                  Icons.health_and_safety_outlined,
                  '${ar(medical)} عندهم أمراض مزمنة أو حساسية أو أدوية',
                ),
                _Line(Icons.folder_copy_outlined, 'ينحفظون بقسم ${b.name}'),
              ],
            ),
          ),
          SectionHeader('وين ينحط كل عمود'),
          BrandCard(
            child: Text(
              'الاسم والهواتف والجنس والميلاد والعنوان والمهنة والإيميل ورقم الملف ← ملف المراجع.\n'
              'الأمراض المزمنة والحساسية والأدوية ← المعلومات الطبية (تطلع تنبيه بملفه).\n'
              'كل صف ← حالة بنوعها وتاريخ زيارتها، والمتفق عليه ← كلفة الحالة، والمدفوع (المتفق − المتبقي) ← دفعة.\n'
              'ملاحظات العمل ← ملاحظة الحالة، والأسنان المكتوبة بيها (مثل LR6) ← مخطط الأسنان.\n'
              'المراجع المكرر بنفس المعرّف يصير ملف واحد، والاستيراد مرة ثانية ما يكرر شي.',
              style: TextStyle(color: b.text, height: 1.8, fontSize: 13),
            ),
          ),
          if (plan.doctors.isNotEmpty && !store.isDoctorAccount) ...[
            SectionHeader('الأطباء'),
            for (final e in plan.doctors.entries) ...[
              BrandCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: b.text,
                            ),
                          ),
                          Text(
                            '${ar(e.value)} حالة بالملف',
                            style: TextStyle(color: b.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back_rounded, size: 18),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _map[e.key],
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(16),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('بدون طبيب'),
                        ),
                        for (final d in store.doctors)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) => setState(() => _map[e.key] = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (plan.warnings.isNotEmpty) ...[
            SectionHeader('تنبيهات (${ar(plan.warnings.length)})'),
            BrandCard(
              child: Text(
                plan.warnings.take(12).join('\n'),
                style: TextStyle(color: b.muted, height: 1.7, fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _go,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done_rounded),
            label: Text(
              _busy ? 'جاري الحفظ…' : 'استيراد ${ar(plan.cases)} حالة',
            ),
          ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Big(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: context.brand.muted, fontSize: 12)),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: b.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: b.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
