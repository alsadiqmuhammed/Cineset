import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../models.dart';
import '../report_pdf.dart';
import '../store.dart';
import 'case_screen.dart';
import 'common.dart';
import 'patients_screen.dart';

/// 07xxxxxxxxx -> 9647xxxxxxxxx (للواتساب).
String internationalPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('0')) return '964${digits.substring(1)}';
  return digits;
}

Future<void> openWhatsApp(String phone, {String? text}) => launchUrl(
  Uri.parse(
    'https://wa.me/${internationalPhone(phone)}'
    '${text == null ? '' : '?text=${Uri.encodeComponent(text)}'}',
  ),
  mode: LaunchMode.externalApplication,
);

/// رسالة تذكير بالموعد جاهزة للواتساب.
String reminderText(Brand b, Patient p, CaseRecord c) {
  final first = p.name.split(' ').first;
  final when = arDateTime(c.nextVisit!);
  return 'مرحباً $first 🌸\n'
      'نذكّرك بموعد ${b.f('مراجعتك', 'جلستك')} بـ${b.name} يوم $when.\n'
      '${Store.instance.clinic.address.isEmpty ? '' : '📍 ${Store.instance.clinic.address}\n'}'
      'إذا تحتاج تأجيل الموعد راسلنا هنا. ننتظرك 🤍';
}

Future<void> callPhone(String phone) =>
    launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}'));

/// مجموع المتبقي على المراجع بكل حالاته.
int _due(Patient p) =>
    p.cases.fold(0, (s, c) => s + ((c.due ?? 0) > 0 ? c.due! : 0));

class PatientScreen extends StatelessWidget {
  final Patient patient;
  const PatientScreen({super.key, required this.patient});

  Future<void> _newCase(BuildContext context) async {
    final r = await showNewCaseSheet(context);
    if (r == null) return;
    final c = CaseRecord(
      id: Store.newId(),
      title: r.$1,
      created: DateTime.now().millisecondsSinceEpoch,
      // حساب الطبيب: الحالة إله دايماً (قواعد الحماية ما تقبل غير هيچ).
      doctorId: Store.instance.myDoctorId ?? r.$2,
    );
    patient.cases.insert(0, c);
    await Store.instance.save();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaseScreen(patient: patient, record: c),
      ),
    );
  }

  Future<void> _menu(BuildContext context, String action) async {
    final b = context.brand;
    switch (action) {
      case 'edit':
        final r = await showPatientDialog(context, existing: patient);
        if (r == null) return;
        patient
          ..name = r.name
          ..phone = r.phone
          ..gender = r.gender ?? patient.gender
          ..birthYear = r.birthYear;
        await Store.instance.save();
      case 'report':
        await shareReport(context, () => patientReport(b, patient));
      case 'delete':
        final ok = await confirm(
          context,
          'حذف ${patient.name}؟',
          'راح تنحذف كل الحالات والصور من التطبيق. ما يمكن التراجع.',
        );
        if (!ok) return;
        await Store.instance.deletePatient(patient);
        if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text('ملف ${b.patient == 'مراجعة' ? 'المراجعة' : 'المراجع'}'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (a) => _menu(context, a),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('تعديل البيانات'),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Text('تقرير كامل PDF'),
                ),
                // حذف المراجع يمسح حالات أطباء ثانيين، فهو للإدارة بس.
                if (!Store.instance.isDoctorAccount)
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _newCase(context),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('حالة جديدة'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            HeroPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (patient.age != null)
                        Pill(
                          '${ar(patient.age!)} سنة',
                          bg: b.accent,
                          fg: b.dark,
                        ),
                      if (patient.gender != null && !b.feminine)
                        Pill(patient.gender!.label, bg: b.accent, fg: b.dark),
                      Pill(
                        '${b.f('مراجع', 'مراجعة')} منذ ${arDate(patient.created)}',
                        bg: Colors.white.withValues(alpha: 0.16),
                      ),
                      if (_due(patient) > 0)
                        Pill(
                          'متبقي ${money(_due(patient))}',
                          bg: const Color(0xFFFFE3DE),
                          fg: const Color(0xFFB3261E),
                        ),
                    ],
                  ),
                  if (patient.phone.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _RoundButton(
                          Icons.call,
                          () => callPhone(patient.phone),
                        ),
                        const SizedBox(width: 8),
                        _RoundButton(
                          Icons.chat,
                          () => openWhatsApp(patient.phone),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SectionHeader('الحالات (${ar(patient.cases.length)})'),
            if (patient.cases.isEmpty)
              EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'ماكو حالات',
                body: b.f(
                  'اضغط "حالة جديدة" وصوّر قبل العلاج.',
                  'اضغطي "حالة جديدة" وصوّري قبل الجلسة.',
                ),
              ),
            for (final c in patient.cases) ...[
              CaseTile(patient: patient, record: c),
              const SizedBox(height: 10),
            ],
            SectionHeader('ملاحظات'),
            _NotesField(patient),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Material(
      color: b.accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: b.dark, size: 20),
        ),
      ),
    );
  }
}

class _NotesField extends StatefulWidget {
  final Patient patient;
  const _NotesField(this.patient);
  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final _c = TextEditingController(text: widget.patient.notes);

  @override
  void dispose() {
    Store.instance.flush();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    minLines: 2,
    maxLines: 6,
    decoration: const InputDecoration(
      hintText: 'حساسية، أدوية، ملاحظات عامة...',
    ),
    onChanged: (v) {
      widget.patient.notes = v;
      Store.instance.saveSoon();
    },
  );
}

class CaseTile extends StatelessWidget {
  final Patient patient;
  final CaseRecord record;
  final bool showPatient;
  const CaseTile({
    super.key,
    required this.patient,
    required this.record,
    this.showPatient = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final c = record;
    final doctor = Store.instance.doctor(c.doctorId);
    return BrandCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaseScreen(patient: patient, record: c),
        ),
      ),
      child: Row(
        children: [
          PhotoThumb(c.before?.path, 'قبل', size: 64),
          const SizedBox(width: 6),
          PhotoThumb(c.after?.path, 'بعد', size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showPatient ? patient.name : c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: b.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (showPatient) c.title,
                    if (doctor != null) doctor.name,
                    arDate(c.created),
                  ].join(' · '),
                  maxLines: 2,
                  style: TextStyle(color: b.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                StatusBadge(c.status),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: b.muted),
        ],
      ),
    );
  }
}

/// (العلاج، id الطبيب) أو null.
Future<(String, String?)?> showNewCaseSheet(BuildContext context) =>
    showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewCaseSheet(),
    );

class _NewCaseSheet extends StatefulWidget {
  const _NewCaseSheet();
  @override
  State<_NewCaseSheet> createState() => _NewCaseSheetState();
}

class _NewCaseSheetState extends State<_NewCaseSheet> {
  final _title = TextEditingController();
  String? _doctor = Store.instance.activeDoctor?.id;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    Navigator.pop(context, (t.isEmpty ? 'حالة' : t, _doctor));
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final doctors = Store.instance.doctors;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حالة جديدة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: b.teethChart ? 'نوع العلاج' : 'نوع الجلسة',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in b.treatments)
                  ChoiceChip(
                    label: Text(t),
                    selected: _title.text == t,
                    onSelected: (_) => setState(() => _title.text = t),
                  ),
              ],
            ),
            if (!Store.instance.isDoctorAccount) ...[
              const SizedBox(height: 16),
              Text('الطبيب', style: TextStyle(color: b.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in doctors)
                    ChoiceChip(
                      avatar: DoctorAvatar(d, size: 22),
                      label: Text(d.name),
                      selected: _doctor == d.id,
                      onSelected: (v) =>
                          setState(() => _doctor = v ? d.id : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('إنشاء')),
          ],
        ),
      ),
    );
  }
}
