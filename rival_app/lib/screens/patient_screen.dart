import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'case_screen.dart';
import 'common.dart';
import 'patients_screen.dart';

const treatments = [
  'ابتسامة هوليود',
  'فينير',
  'تقويم',
  'تبييض',
  'زراعة',
  'حشوات تجميلية',
];

/// 07xxxxxxxxx -> 9647xxxxxxxxx (للواتساب).
String internationalPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('0')) return '964${digits.substring(1)}';
  return digits;
}

class PatientScreen extends StatelessWidget {
  final Patient patient;
  const PatientScreen({super.key, required this.patient});

  Future<void> _newCase(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _CaseTitleDialog(),
    );
    if (title == null) return;
    final c = CaseRecord(
      id: Store.newId(),
      title: title,
      created: DateTime.now().millisecondsSinceEpoch,
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
    if (action == 'edit') {
      final r = await showPatientDialog(context, existing: patient);
      if (r == null) return;
      patient
        ..name = r.$1
        ..phone = r.$2;
      await Store.instance.save();
    } else if (action == 'delete') {
      final ok = await confirm(
        context,
        'حذف ${patient.name}؟',
        'راح تنحذف كل حالاته وصوره من التطبيق. ما يمكن التراجع.',
      );
      if (!ok) return;
      await Store.instance.deletePatient(patient);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(patient.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (a) => _menu(context, a),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'delete', child: Text('حذف المراجع')),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (patient.phone.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, color: kGold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          patient.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'اتصال',
                        onPressed: () =>
                            launchUrl(Uri.parse('tel:${patient.phone}')),
                        icon: const Icon(Icons.call),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'واتساب',
                        onPressed: () => launchUrl(
                          Uri.parse(
                            'https://wa.me/${internationalPhone(patient.phone)}',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.chat_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (patient.cases.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'ماكو حالات',
                  body: 'اضغط "حالة جديدة" وصوّر قبل العلاج.',
                ),
              ),
            for (final c in patient.cases) ...[
              _CaseTile(patient, c),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  final Patient patient;
  final CaseRecord c;
  const _CaseTile(this.patient, this.c);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaseScreen(patient: patient, record: c),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PhotoThumb(c.before?.path, 'قبل', size: 72),
              const SizedBox(width: 8),
              PhotoThumb(c.after?.path, 'بعد', size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(c.created),
                      style: const TextStyle(color: kMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseTitleDialog extends StatefulWidget {
  const _CaseTitleDialog();
  @override
  State<_CaseTitleDialog> createState() => _CaseTitleDialogState();
}

class _CaseTitleDialogState extends State<_CaseTitleDialog> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    Navigator.pop(context, t.isEmpty ? 'حالة' : t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حالة جديدة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'نوع العلاج'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in treatments)
                ActionChip(
                  label: Text(t),
                  onPressed: () => setState(() => _title.text = t),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('إنشاء')),
      ],
    );
  }
}
