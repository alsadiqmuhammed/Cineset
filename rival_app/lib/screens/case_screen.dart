import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../align.dart';
import '../brand.dart';
import '../models.dart';
import '../render.dart';
import '../report_pdf.dart';
import '../store.dart';
import 'common.dart';
import 'compose_screen.dart';
import 'money.dart';
import 'patient_screen.dart' show openWhatsApp, reminderText;
import 'points_editor.dart';
import 'teeth_chart.dart';
import 'video_screen.dart';

enum Slot { before, after }

class CaseScreen extends StatefulWidget {
  final Patient patient;
  final CaseRecord record;
  const CaseScreen({super.key, required this.patient, required this.record});

  @override
  State<CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends State<CaseScreen> {
  late final _aligner = AutoAligner(Store.instance.brand.alignTarget);
  late final _note = TextEditingController(text: widget.record.note);
  bool _busy = false;

  CaseRecord get c => widget.record;

  @override
  void dispose() {
    _aligner.close();
    if (_note.text != c.note) {
      c.note = _note.text;
      Store.instance.save();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {});
    await Store.instance.save();
  }

  Photo? _get(Slot s) => s == Slot.before ? c.before : c.after;
  void _set(Slot s, Photo? p) => s == Slot.before ? c.before = p : c.after = p;

  Future<void> _pick(Slot slot, ImageSource source) async {
    final b = context.brand;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final path = await Store.instance.importPhoto(picked.path);
      final old = _get(slot);
      if (old != null) {
        evictImage(old.path);
        await Store.instance.deletePhoto(old);
      }
      var photo = Photo(path, taken: DateTime.now().millisecondsSinceEpoch);
      photo = await _tryAlign(photo) ?? photo;
      _set(slot, photo);
      await Store.instance.save();
      if (mounted && !photo.aligned) {
        toast(
          context,
          b.f(
            'ما لگيت وجه بالصورة. حدد نقطتي المحاذاة بإيدك.',
            'ما لگيت وجه بالصورة. حددي نقطتي المحاذاة بإيدچ.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Photo?> _tryAlign(Photo p) async {
    try {
      return await _aligner.align(p);
    } catch (_) {
      return null;
    }
  }

  Future<void> _alignBoth() async {
    setState(() => _busy = true);
    var missed = 0;
    for (final s in Slot.values) {
      final p = _get(s);
      if (p == null) continue;
      final aligned = await _tryAlign(p);
      if (aligned == null) {
        missed++;
      } else {
        _set(s, aligned);
      }
    }
    await Store.instance.save();
    if (!mounted) return;
    setState(() => _busy = false);
    toast(
      context,
      missed == 0
          ? 'تمت المحاذاة. راجع المعاينة.'
          : 'ما لگيت وجه بـ ${ar(missed)} صورة. حدد النقاط يدوياً.',
    );
  }

  Future<void> _editPoints(Slot slot) async {
    final p = _get(slot);
    if (p == null) return;
    final edited = await Navigator.push<Photo>(
      context,
      MaterialPageRoute(builder: (_) => PointsEditor(photo: p)),
    );
    if (edited == null) return;
    _set(slot, edited);
    await _save();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      'حذف الحالة؟',
      'راح تنحذف صور قبل وبعد والزيارات لهذه الحالة.',
    );
    if (!ok) return;
    await Store.instance.deleteCase(widget.patient, c);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _rename() async {
    final ctl = TextEditingController(text: c.title);
    final b = context.brand;
    final t = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نوع العلاج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctl, autofocus: true),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in b.treatments)
                  ActionChip(label: Text(t), onPressed: () => ctl.text = t),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (t == null || t.isEmpty) return;
    c.title = t;
    await _save();
  }

  Future<void> _addVisit([Visit? existing]) async {
    final r = await showModalBottomSheet<Visit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VisitSheet(existing: existing),
    );
    if (r == null) return;
    if (existing == null) {
      c.visits.add(r);
    }
    c.visits.sort((a, b) => a.date.compareTo(b.date));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final ready = c.before != null && c.after != null;
    final store = Store.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.title),
        actions: [
          IconButton(
            tooltip: 'تعديل نوع العلاج',
            onPressed: _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'حذف الحالة',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Pill(widget.patient.name, icon: Icons.person),
                  Pill(
                    arDate(c.created),
                    bg: b.accent.withValues(alpha: 0.35),
                    fg: b.dark,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _slotCard(Slot.before, 'قبل')),
                  const SizedBox(width: 12),
                  Expanded(child: _slotCard(Slot.after, 'بعد')),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: ready && !_busy ? _alignBoth : null,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('محاذاة تلقائية بالذكاء الاصطناعي'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: ready
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ComposeScreen(
                                  patient: widget.patient,
                                  record: c,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.compare),
                      label: const Text('تصميم قبل وبعد'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: ready
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoScreen(record: c),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.movie_creation_outlined),
                      label: const Text('فيديو التحوّل'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => shareReport(
                  context,
                  () => caseReport(b, widget.patient, c),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('تقرير الحالة PDF'),
              ),
              SectionHeader('الحالة والطبيب'),
              BrandCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<CaseStatus>(
                      segments: [
                        for (final s in CaseStatus.values)
                          ButtonSegment(value: s, label: Text(s.label)),
                      ],
                      selected: {c.status},
                      onSelectionChanged: (s) {
                        c.status = s.first;
                        c.completed = c.status == CaseStatus.done
                            ? DateTime.now().millisecondsSinceEpoch
                            : null;
                        _save();
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final d in store.doctors)
                          if (!store.isDoctorAccount || d.id == c.doctorId)
                            ChoiceChip(
                              avatar: DoctorAvatar(d, size: 22),
                              label: Text(d.name),
                              selected: c.doctorId == d.id,
                              // الطبيب ما ينقل حالته لغيره؛ الإدارة تنقلها.
                              onSelected: store.isDoctorAccount
                                  ? null
                                  : (v) {
                                      c.doctorId = v ? d.id : null;
                                      _save();
                                    },
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              if (b.teethChart) ...[
                SectionHeader(
                  'الأسنان المعالجة',
                  trailing: c.teeth.isEmpty
                      ? null
                      : Text(
                          ar(c.teeth.length),
                          style: TextStyle(
                            color: b.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                BrandCard(
                  child: TeethChart(
                    selected: c.teeth.toSet(),
                    age: widget.patient.age,
                    deciduous: c.deciduous?.toSet(),
                    onDeciduous: (d) {
                      c.deciduous = d == null ? null : (d.toList()..sort());
                      _save();
                    },
                    onToggle: (t) {
                      c.teeth.contains(t) ? c.teeth.remove(t) : c.teeth.add(t);
                      c.teeth.sort();
                      _save();
                    },
                  ),
                ),
              ] else ...[
                SectionHeader(
                  'الأجزاء المعالجة',
                  trailing: c.areas.isEmpty
                      ? null
                      : Text(
                          ar(c.areas.length),
                          style: TextStyle(
                            color: b.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                BrandCard(
                  child: FaceMap(
                    selected: c.areas,
                    doses: c.doses,
                    onToggle: (id) {
                      if (c.areas.remove(id)) {
                        c.doses.remove(id);
                      } else {
                        c.areas.add(id);
                      }
                      _save();
                    },
                    onDose: (id, dose) {
                      dose.isEmpty ? c.doses.remove(id) : c.doses[id] = dose;
                      _save();
                    },
                  ),
                ),
              ],
              SectionHeader(
                'الحساب',
                trailing: (c.due ?? 0) > 0
                    ? Text(
                        'متبقي ${money(c.due!)}',
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              CaseMoneyCard(record: c, onChanged: _save),
              SectionHeader(b.f('المراجعة القادمة', 'الجلسة القادمة')),
              BrandCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_note, color: b.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.nextVisit == null
                            ? 'ما محدد'
                            : arDateTime(c.nextVisit!),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.nextVisit == null ? b.muted : b.text,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: c.nextVisit == null
                              ? now.add(const Duration(days: 7))
                              : DateTime.fromMillisecondsSinceEpoch(
                                  c.nextVisit!,
                                ),
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 3),
                        );
                        if (d == null || !context.mounted) return;
                        final old = c.nextVisit == null
                            ? null
                            : DateTime.fromMillisecondsSinceEpoch(c.nextVisit!);
                        final t = await showTimePicker(
                          context: context,
                          helpText: 'الساعة (اختياري)',
                          cancelText: 'بدون ساعة',
                          initialTime:
                              old == null || (old.hour == 0 && old.minute == 0)
                              ? const TimeOfDay(hour: 17, minute: 0)
                              : TimeOfDay.fromDateTime(old),
                        );
                        c.nextVisit = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t?.hour ?? 0,
                          t?.minute ?? 0,
                        ).millisecondsSinceEpoch;
                        _save();
                      },
                      child: Text(c.nextVisit == null ? 'حدد موعد' : 'غيّر'),
                    ),
                    if (c.nextVisit != null &&
                        widget.patient.phone.trim().isNotEmpty)
                      IconButton(
                        tooltip: 'ذكّر بالواتساب',
                        onPressed: () => openWhatsApp(
                          widget.patient.phone,
                          text: reminderText(b, widget.patient, c),
                        ),
                        icon: Icon(Icons.chat, size: 20, color: b.primary),
                      ),
                    if (c.nextVisit != null)
                      IconButton(
                        tooltip: 'شيل الموعد',
                        onPressed: () {
                          c.nextVisit = null;
                          _save();
                        },
                        icon: Icon(Icons.close, size: 18, color: b.muted),
                      ),
                  ],
                ),
              ),
              SectionHeader(
                b.teethChart ? 'الزيارات' : 'الجلسات',
                trailing: TextButton.icon(
                  onPressed: _addVisit,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                ),
              ),
              if (c.visits.isEmpty)
                Text(
                  b.f(
                    'سجّل كل زيارة بتاريخها وشنو انسوّى بيها.',
                    'سجّلي كل جلسة بتاريخها وشنو انسوّى بيها.',
                  ),
                  style: TextStyle(color: b.muted),
                ),
              for (var i = 0; i < c.visits.length; i++)
                _VisitTile(
                  index: i,
                  visit: c.visits[i],
                  last: i == c.visits.length - 1,
                  onTap: () => _addVisit(c.visits[i]),
                  onDelete: () {
                    c.visits.removeAt(i);
                    _save();
                  },
                ),
              SectionHeader('ملاحظات الحالة'),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 8,
                onChanged: (v) => c.note = v,
                decoration: const InputDecoration(
                  hintText: 'التشخيص، المواد المستخدمة، التوصيات...',
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _slotCard(Slot slot, String label) {
    final b = context.brand;
    final p = _get(slot);
    final after = slot == Slot.after;
    return BrandCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: p == null
                ? Container(
                    color: b.line.withValues(alpha: 0.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: b.muted,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 20,
                            color: b.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(p.path),
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Pill(label, bg: after ? b.primary : b.dark),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Pill(
                          p.aligned ? 'محاذاة جاهزة' : 'بدون محاذاة',
                          bg: Colors.black54,
                          fg: p.aligned
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'كاميرا',
                onPressed: _busy ? null : () => _pick(slot, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: 'المعرض',
                onPressed: _busy
                    ? null
                    : () => _pick(slot, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
              ),
              IconButton(
                tooltip: 'نقاط المحاذاة',
                onPressed: p == null || _busy ? null : () => _editPoints(slot),
                icon: const Icon(Icons.control_point),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final int index;
  final Visit visit;
  final bool last;
  final VoidCallback onTap, onDelete;
  const _VisitTile({
    required this.index,
    required this.visit,
    required this.last,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: b.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  ar(index + 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!last) Expanded(child: Container(width: 2, color: b.line)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrandCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                onTap: onTap,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arDate(visit.date),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: b.text,
                            ),
                          ),
                          if (visit.note.isNotEmpty)
                            Text(visit.note, style: TextStyle(color: b.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(Icons.close, size: 18, color: b.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitSheet extends StatefulWidget {
  final Visit? existing;
  const _VisitSheet({this.existing});
  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  late DateTime _date = widget.existing == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(widget.existing!.date);
  late final _note = TextEditingController(text: widget.existing?.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Padding(
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
            b.teethChart ? 'زيارة' : 'جلسة',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
            icon: const Icon(Icons.event),
            label: Text(arDate(_date.millisecondsSinceEpoch)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'شنو انسوّى'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final v = widget.existing ?? Visit(id: Store.newId(), date: 0);
              v
                ..date = _date.millisecondsSinceEpoch
                ..note = _note.text.trim();
              Navigator.pop(context, v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
