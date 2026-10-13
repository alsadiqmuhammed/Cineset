import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../brand.dart';
import '../models.dart';
import '../render.dart';
import '../store.dart';
import 'common.dart';

class DoctorEditScreen extends StatefulWidget {
  final Doctor? doctor;
  const DoctorEditScreen({super.key, this.doctor});

  @override
  State<DoctorEditScreen> createState() => _DoctorEditScreenState();
}

class _DoctorEditScreenState extends State<DoctorEditScreen> {
  late final Doctor _d =
      widget.doctor ?? Doctor(id: Store.newId(), name: 'د. ');
  late final _name = TextEditingController(text: _d.name);
  late final _specialty = TextEditingController(text: _d.specialty);
  late final _phone = TextEditingController(text: _d.phone);
  late final _bio = TextEditingController(text: _d.bio);
  late final _services = TextEditingController(text: _d.services.join('، '));
  String? _photo;
  late String? _signature = _d.signature;
  late String? _stamp = _d.stamp;
  late String? _portrait = _d.portrait;

  @override
  void initState() {
    super.initState();
    _photo = _d.photo;
  }

  /// PNG بدون ضغط حتى تبقى الشفافية.
  Future<String?> _pickPng() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return importPicked(picked);
  }

  @override
  void dispose() {
    for (final c in [_name, _specialty, _phone, _bio, _services]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (picked == null) return;
    final path = await importPicked(picked);
    setState(() => _photo = path);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || name == 'د.') {
      toast(context, 'اكتب الاسم');
      return;
    }
    for (final (old, now) in [
      (_d.photo, _photo),
      (_d.signature, _signature),
      (_d.stamp, _stamp),
      (_d.portrait, _portrait),
    ]) {
      if (old != null && old != now) evictImage(old);
    }
    _d
      ..name = name
      ..specialty = _specialty.text.trim()
      ..phone = _phone.text.trim()
      ..bio = _bio.text.trim()
      ..photo = _photo
      ..signature = _signature
      ..stamp = _stamp
      ..portrait = _portrait;
    _d.services
      ..clear()
      ..addAll(
        _services.text
            .split(RegExp('[،,\n]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    final store = Store.instance;
    if (!store.doctors.contains(_d)) {
      await store.addDoctor(_d);
    } else {
      await store.saveAll();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      'حذف ${_d.name}؟',
      'الحالات تبقى، بس تنشال منها نسبة الطبيب.',
    );
    if (!ok) return;
    await Store.instance.deleteDoctor(_d);
    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final preview = Doctor(id: _d.id, name: _name.text, photo: _photo);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctor == null ? 'طبيب جديد' : 'تعديل الملف'),
        actions: [
          if (widget.doctor != null && !Store.instance.isDoctorAccount)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Stack(
              children: [
                DoctorAvatar(preview, size: 110),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: b.accent),
                    onPressed: _pickPhoto,
                    icon: Icon(Icons.photo_camera, color: b.dark),
                  ),
                ),
              ],
            ),
          ),
          if (_photo != null)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _photo = null),
                child: const Text('شيل الصورة'),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialty,
            decoration: const InputDecoration(labelText: 'الاختصاص'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم الهاتف / واتساب'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _services,
            decoration: const InputDecoration(
              labelText: 'الخدمات',
              hintText: 'مثلاً: فلر، بوتوكس، نضارة البشرة',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'نبذة',
              hintText: 'الشهادة، سنين الخبرة، الاهتمامات...',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'صورة بطاقة الطبيب',
            style: TextStyle(color: b.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'صورة PNG مقصوصة بدون خلفية (من الصدر وفوق). تطلع بارزة ببطاقة الطبيب وبملفه.',
            style: TextStyle(color: b.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          _PngTile(
            label: 'الصورة المقصوصة',
            hint: 'PNG شفاف',
            path: _portrait,
            height: 170,
            onPick: () async {
              final p = await _pickPng();
              if (p != null) setState(() => _portrait = p);
            },
            onClear: () => setState(() => _portrait = null),
          ),
          const SizedBox(height: 18),
          Text(
            'للتصاميم والتقارير',
            style: TextStyle(color: b.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PngTile(
                  label: 'التوقيع',
                  hint: 'PNG شفاف',
                  path: _signature,
                  onPick: () async {
                    final p = await _pickPng();
                    if (p != null) setState(() => _signature = p);
                  },
                  onClear: () => setState(() => _signature = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PngTile(
                  label: 'صورة خاصة',
                  hint: 'ختم أو شعار شخصي',
                  path: _stamp,
                  onPick: () async {
                    final p = await _pickPng();
                    if (p != null) setState(() => _stamp = p);
                  },
                  onClear: () => setState(() => _stamp = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
    );
  }
}

/// خانة صورة PNG (توقيع أو ختم) على خلفية مربعات حتى تبين الشفافية.
class _PngTile extends StatelessWidget {
  final String label, hint;
  final String? path;
  final VoidCallback onPick, onClear;
  final double height;
  const _PngTile({
    required this.label,
    required this.hint,
    required this.path,
    required this.onPick,
    required this.onClear,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Column(
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: b.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: b.line),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(8),
            child: path == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: b.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        hint,
                        style: TextStyle(color: b.muted, fontSize: 11),
                      ),
                    ],
                  )
                : StoredImage(
                    errorBuilder: missingPhoto,
                    path!,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
        if (path != null)
          TextButton(onPressed: onClear, child: Text('شيل $label')),
      ],
    );
  }
}
