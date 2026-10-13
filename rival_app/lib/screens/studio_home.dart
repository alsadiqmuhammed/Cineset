import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../align.dart';
import '../brand.dart';
import '../design.dart';
import '../main_studio.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'compose_screen.dart';
import 'design_controls.dart';

/// الشاشة الرئيسية لريڤال ستوديو: القسم، صورتين، وتصميم.
class StudioHome extends StatefulWidget {
  const StudioHome({super.key});

  @override
  State<StudioHome> createState() => _StudioHomeState();
}

class _StudioHomeState extends State<StudioHome> {
  final Map<Which, Photo> _photos = {};
  final Set<Which> _busy = {};
  late final _aligner = AutoAligner(Store.instance.brand.alignTarget);
  List<File> _designs = [];

  @override
  void initState() {
    super.initState();
    _loadDesigns();
  }

  @override
  void dispose() {
    _aligner.close();
    super.dispose();
  }

  void _loadDesigns() {
    final dir = Store.instance.exportsDir;
    final files = dir.existsSync()
        ? dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.png'))
              .toList()
        : <File>[];
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    setState(() => _designs = files);
  }

  Future<void> _pick(Which which) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('تصوير صورة ${which.label}'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photos[which] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('شيل الصورة'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photos.remove(which));
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 95,
    );
    if (picked == null) return;
    setState(() => _busy.add(which));
    try {
      var photo = Photo(
        await importPicked(picked),
        taken: DateTime.now().millisecondsSinceEpoch,
      );
      // المطابقة التلقائية (الفم أو العينين) حتى الصورتين يطلعن بنفس الحجم.
      try {
        photo = await _aligner.align(photo) ?? photo;
      } catch (_) {
        // بدون كشف الوجه تبقى الصورة بضبط تلقائي عادي.
      }
      if (mounted) setState(() => _photos[which] = photo);
    } finally {
      if (mounted) setState(() => _busy.remove(which));
    }
  }

  Future<void> _design() async {
    final after = _photos[Which.after] ?? _photos[Which.before];
    if (after == null) return;
    final before = _photos[Which.after] == null ? null : _photos[Which.before];
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeScreen.photos(before: before, after: after),
      ),
    );
    _loadDesigns();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final count = templatesFor(b.section).length;
    final ready = _photos.isNotEmpty && _busy.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                GlossyEmblem(section: b.section, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ريڤال ستوديو',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: b.text,
                        ),
                      ),
                      Text(
                        'تصميم حالات قبل وبعد · ${ar(count)} قالب',
                        style: TextStyle(color: b.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NeuTabs(
              labels: const ['عيادة ريڤال', 'ريڤال بيوتي'],
              index: b.section == Section.dental ? 0 : 1,
              onChanged: (i) =>
                  StudioApp.of(context)
                      .choose(i == 0 ? Section.dental : Section.beauty),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (final w in Which.values) ...[
                  Expanded(
                    child: _PhotoTile(
                      which: w,
                      photo: _photos[w],
                      busy: _busy.contains(w),
                      onTap: () => _pick(w),
                    ),
                  ),
                  if (w == Which.before) const SizedBox(width: 14),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'صورة وحدة تكفي لقوالب الصورة الوحدة. المطابقة بين الصورتين تلقائية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: b.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: ready ? 1 : 0.45,
              child: GestureDetector(
                onTap: ready ? _design : null,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: b.action,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: ready ? b.actionShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'صمّم الحالة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(_photos.clear),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('حالة جديدة'),
              ),
            ],
            const SizedBox(height: 26),
            Text(
              'قوالب ${b.name}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: b.text,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final t = templatesFor(b.section)[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: b.line.withValues(alpha: 0.5),
                      child: Image.asset(
                        t.asset,
                        height: 150,
                        fit: BoxFit.contain,
                        cacheHeight: 300,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_designs.isNotEmpty) ...[
              const SizedBox(height: 26),
              Text(
                'آخر التصاميم',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: b.text,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
                children: [
                  for (final f in _designs.take(12))
                    GestureDetector(
                      onTap: () => _designActions(f),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          f,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'التصاميم تنمسح من هنا بعد ٣ أيام؛ احفظها بالمعرض.',
                textAlign: TextAlign.center,
                style: TextStyle(color: b.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _designActions(File f) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('مشاركة'),
              onTap: () {
                Navigator.pop(sheet);
                shareFile(f.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('حفظ بالمعرض'),
              onTap: () {
                Navigator.pop(sheet);
                saveToGallery(context, f.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('حذف'),
              onTap: () {
                Navigator.pop(sheet);
                f.deleteSync();
                _loadDesigns();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Which which;
  final Photo? photo;
  final bool busy;
  final VoidCallback onTap;
  const _PhotoTile({
    required this.which,
    required this.photo,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final p = photo;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AspectRatio(
        aspectRatio: 0.78,
        child: Container(
          decoration: BoxDecoration(
            color: b.glass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: b.glassEdge, width: 1.5),
            boxShadow: b.raised(0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (p != null)
                Image.file(File(p.path), fit: BoxFit.cover, cacheWidth: 500)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: b.action,
                        shape: BoxShape.circle,
                        boxShadow: b.actionShadow,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'صورة ${which.label}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: b.text,
                      ),
                    ),
                  ],
                ),
              if (busy)
                Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Colors.white),
                ),
              if (p != null)
                PositionedDirectional(
                  top: 10,
                  start: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: which == Which.before ? b.dark : b.primaryDeep,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      which.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
