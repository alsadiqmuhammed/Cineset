import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'patient_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final result = await showPatientDialog(context);
    if (result == null || !mounted) return;
    final p = await Store.instance.addPatient(result.$1, result.$2);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientScreen(patient: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final q = _search.text.trim();
        final list = Store.instance.patients
            .where(
              (p) => q.isEmpty || p.name.contains(q) || p.phone.contains(q),
            )
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Column(
              children: [
                Text(clinicName),
                Text(
                  'أرشيف المراجعين',
                  style: TextStyle(fontSize: 12, color: kGold),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('مراجع جديد'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الهاتف',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: q.isEmpty ? 'ماكو مراجعين بعد' : 'ماكو نتائج',
                        body: q.isEmpty
                            ? 'أضف أول مراجع واحفظ صور قبل وبعد تحت اسمه.'
                            : 'جرّب اسم أو رقم ثاني.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _PatientTile(list[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientTile extends StatelessWidget {
  final Patient p;
  const _PatientTile(this.p);

  @override
  Widget build(BuildContext context) {
    final latest = p.cases.isEmpty ? null : p.cases.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PatientScreen(patient: p)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PhotoThumb(
                latest?.after?.path ?? latest?.before?.path,
                p.name.characters.first,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.phone.isEmpty ? '—' : p.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: kMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${p.cases.length} حالة',
                style: const TextStyle(color: kGold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يرجع (الاسم، الهاتف) أو null إذا انلغى.
Future<(String, String)?> showPatientDialog(
  BuildContext context, {
  Patient? existing,
}) {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => _PatientDialog(existing: existing),
  );
}

class _PatientDialog extends StatefulWidget {
  final Patient? existing;
  const _PatientDialog({this.existing});
  @override
  State<_PatientDialog> createState() => _PatientDialogState();
}

class _PatientDialogState extends State<_PatientDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _phone.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'مراجع جديد' : 'تعديل المراجع'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'رقم الهاتف'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
