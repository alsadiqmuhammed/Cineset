import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../align.dart';
import '../models.dart';
import '../render.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'compose_screen.dart';
import 'points_editor.dart';
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
  final _aligner = AutoAligner();
  late final _note = TextEditingController(text: widget.record.note);
  bool _busy = false;

  CaseRecord get c => widget.record;

  @override
  void dispose() {
    _aligner.close();
    _note.dispose();
    super.dispose();
  }

  Photo? _get(Slot s) => s == Slot.before ? c.before : c.after;
  void _set(Slot s, Photo? p) => s == Slot.before ? c.before = p : c.after = p;

  Future<void> _pick(Slot slot, ImageSource source) async {
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
      var photo = Photo(path);
      photo = await _tryAlign(photo) ?? photo;
      _set(slot, photo);
      await Store.instance.save();
      if (mounted && !photo.aligned) {
        toast(context, 'ما لگيت وجه بالصورة. حدد نقطتي المحاذاة بإيدك.');
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
          : 'ما لگيت وجه بـ $missed صورة. حدد النقاط بإيدك.',
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
    setState(() => _set(slot, edited));
    await Store.instance.save();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      'حذف الحالة؟',
      'راح تنحذف صور قبل وبعد لهذه الحالة.',
    );
    if (!ok) return;
    await Store.instance.deleteCase(widget.patient, c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ready = c.before != null && c.after != null;
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        if (_note.text != c.note) {
          c.note = _note.text;
          Store.instance.save();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.title),
          actions: [
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  widget.patient.name,
                  style: const TextStyle(color: kGold, fontSize: 15),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: ready
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComposeScreen(record: c),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.compare),
                  label: const Text('تصميم صورة قبل وبعد'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: ready
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoScreen(record: c),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: const Text('فيديو التحوّل (Reel / TikTok)'),
                ),
                if (!ready)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'أضف صورة قبل وصورة بعد حتى تفتح التصاميم.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted),
                    ),
                  ),
                const SizedBox(height: 24),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الحالة',
                  ),
                ),
              ],
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x88000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotCard(Slot slot, String label) {
    final p = _get(slot);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: p == null
                ? Container(
                    color: kSurfaceHigh,
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 22, color: kMuted),
                      ),
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
                        child: _chip(label, kGold, const Color(0xFF1A1408)),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: p.aligned
                            ? _chip(
                                'محاذاة جاهزة',
                                Colors.black54,
                                Colors.greenAccent,
                              )
                            : _chip(
                                'بدون محاذاة',
                                Colors.black54,
                                Colors.orangeAccent,
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
                tooltip: 'تحديد نقاط المحاذاة',
                onPressed: p == null || _busy ? null : () => _editPoints(slot),
                icon: const Icon(Icons.control_point),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
