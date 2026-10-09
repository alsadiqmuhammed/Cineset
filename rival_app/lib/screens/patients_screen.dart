import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'patient_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

enum _Filter { all, active, done }

class _PatientsScreenState extends State<PatientsScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final r = await showPatientDialog(context);
    if (r == null || !mounted) return;
    final p = await Store.instance.addPatient(
      r.name,
      r.phone,
      gender: r.gender,
      birthYear: r.birthYear,
      birthDate: r.birthDate,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientScreen(patient: p)),
    );
  }

  bool _matches(Patient p) {
    final q = searchKey(_search.text.trim());
    if (q.isNotEmpty &&
        !searchKey(p.name).contains(q) &&
        !searchKey(p.phone).contains(q)) {
      return false;
    }
    return switch (_filter) {
      _Filter.all => true,
      _Filter.active => p.cases.any((c) => c.status == CaseStatus.active),
      _Filter.done =>
        p.cases.isNotEmpty && p.cases.every((c) => c.status == CaseStatus.done),
    };
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final list = Store.instance.patients.where(_matches).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(b.patients),
            actions: const [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 12),
                child: SectionSwitch(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(b.newPatient),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الهاتف',
                    prefixIcon: Icon(Icons.search, color: b.muted),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (f, label) in [
                      (_Filter.all, 'الكل'),
                      (_Filter.active, 'قيد العلاج'),
                      (_Filter.done, 'مكتملة'),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: Store.instance.patients.isEmpty
                            ? 'ماكو ${b.patients} بعد'
                            : 'ماكو نتائج',
                        body: Store.instance.patients.isEmpty
                            ? b.f(
                                'أضف أول مراجع واحفظ صور قبل وبعد تحت اسمه.',
                                'أضيفي أول مراجعة واحفظي صور قبل وبعد تحت اسمها.',
                              )
                            : 'جرّب اسم أو رقم ثاني، أو غيّر الفلتر.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
    final b = context.brand;
    final latest = p.cases.isEmpty ? null : p.cases.first;
    final active = p.cases.where((c) => c.status == CaseStatus.active).length;
    return BrandCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PatientScreen(patient: p)),
      ),
      child: Row(
        children: [
          PhotoThumb(
            latest?.after?.path ?? latest?.before?.path,
            p.name.isEmpty ? '؟' : p.name.substring(0, 1),
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: b.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (p.phone.isNotEmpty) p.phone,
                    if (p.age != null) '${ar(p.age!)} سنة',
                  ].join('  ·  '),
                  style: TextStyle(color: b.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${ar(p.cases.length)} حالة',
                style: TextStyle(color: b.primary, fontWeight: FontWeight.w800),
              ),
              if (active > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${ar(active)} قيد العلاج',
                  style: TextStyle(color: b.muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class PatientInput {
  final String name, phone;
  final Gender? gender;
  final int? birthYear;
  final int? birthDate;
  const PatientInput(
    this.name,
    this.phone,
    this.gender,
    this.birthYear, [
    this.birthDate,
  ]);
}

Future<PatientInput?> showPatientDialog(
  BuildContext context, {
  Patient? existing,
}) {
  return showModalBottomSheet<PatientInput>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PatientSheet(existing: existing),
  );
}

class _PatientSheet extends StatefulWidget {
  final Patient? existing;
  const _PatientSheet({this.existing});
  @override
  State<_PatientSheet> createState() => _PatientSheetState();
}

class _PatientSheetState extends State<_PatientSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _age = TextEditingController(
    text: widget.existing?.age?.toString() ?? '',
  );
  late Gender? _gender = widget.existing?.gender;
  late DateTime? _birth = widget.existing?.birthday;

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final age = int.tryParse(latinDigits(_age.text.trim()));
    final d = await showDatePicker(
      context: context,
      initialDate:
          _birth ?? DateTime(now.year - (age ?? 25), now.month, now.day),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'تاريخ الميلاد',
    );
    if (d == null) return;
    setState(() {
      _birth = DateTime(d.year, d.month, d.day);
      var a = now.year - d.year;
      if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
        a--;
      }
      _age.text = '$a';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final age = int.tryParse(latinDigits(_age.text.trim()));
    Navigator.pop(
      context,
      PatientInput(
        name,
        _phone.text.trim(),
        _gender,
        _birth?.year ?? (age == null ? null : DateTime.now().year - age),
        _birth?.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
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
            Text(
              widget.existing == null ? b.newPatient : 'تعديل البيانات',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_birth != null) setState(() => _birth = null);
                    },
                    decoration: const InputDecoration(labelText: 'العمر'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickBirth,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'تاريخ الميلاد (لتهنئة عيد الميلاد)',
                  prefixIcon: Icon(Icons.cake_outlined, color: b.primary),
                  suffixIcon: _birth == null
                      ? null
                      : IconButton(
                          tooltip: 'مسح',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _birth = null),
                        ),
                ),
                child: Text(
                  _birth == null
                      ? 'اختياري'
                      : arDate(_birth!.millisecondsSinceEpoch),
                  style: TextStyle(color: _birth == null ? b.muted : b.text),
                ),
              ),
            ),
            if (!b.feminine) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final g in Gender.values)
                    ChoiceChip(
                      label: Text(g.label),
                      selected: _gender == g,
                      onSelected: (v) => setState(() => _gender = v ? g : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}
