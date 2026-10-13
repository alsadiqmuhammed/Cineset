import 'dart:convert';
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
import 'ghost_camera.dart';
import 'studio_controls.dart';
import 'template_gallery.dart';

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
  List<_Case> _cases = [];

  @override
  void initState() {
    super.initState();
    _loadDesigns();
    _loadCases();
  }

  File get _casesFile => File('${Store.instance.root.path}/studio_cases.json');

  /// الحالات السابقة (صور القبل والبعد) حتى ترجع تصمم منها بقالب ثاني.
  void _loadCases() {
    try {
      final f = _casesFile;
      if (!f.existsSync()) return;
      final list = (jsonDecode(f.readAsStringSync()) as List)
          .map((e) => _Case.fromJson(e as Map<String, dynamic>))
          .where((c) => File(c.after.path).existsSync())
          .toList();
      setState(() => _cases = list);
    } catch (_) {
      // ملف تالف: نبدي من جديد.
    }
  }

  void _saveCases() {
    try {
      _casesFile.writeAsStringSync(
        jsonEncode([for (final c in _cases) c.toJson()]),
      );
    } catch (_) {}
  }

  _Case _remember(Photo? before, Photo after) {
    final old = _cases.where((c) => c.after.path == after.path).firstOrNull;
    _cases.removeWhere((c) => c.after.path == after.path);
    final c = _Case(
      before,
      after,
      DateTime.now(),
      templateId: old?.templateId,
      adjust: old?.adjust ?? const {},
      flipped: old?.flipped ?? const {},
    );
    _cases.insert(0, c);
    if (_cases.length > 24) _cases = _cases.sublist(0, 24);
    _saveCases();
    return c;
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

  List<Widget> _staggered(List<Widget> items) => [
    for (final (i, w) in items.indexed) Entrance(index: i, child: w),
  ];

  Future<void> _pick(Which which) async {
    final other = _photos[which == Which.after ? Which.before : Which.after];
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (other != null)
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: Text('تصوير ${which.label} بالصورة الشبحية'),
                subtitle: Text(
                  'صورة ال${which == Which.after ? 'قبل' : 'بعد'} تبين شفافة فوق الكاميرا حتى تطابقها',
                ),
                onTap: () => Navigator.pop(context, 'ghost'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('تصوير صورة ${which.label}'),
              subtitle: const Text('ويّا خطوط مساعدة'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('من المعرض'),
              onTap: () => Navigator.pop(context, 'gallery'),
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
    if (source == null || !mounted) return;
    final section = Store.instance.section;
    String? path;
    if (source == 'gallery') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 95,
      );
      if (picked != null) path = await importPicked(picked);
    } else {
      final shot = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => GhostCamera(
            title: 'صورة ${which.label}',
            section: section,
            ghost: source == 'ghost' ? other?.path : null,
          ),
        ),
      );
      if (shot != null) path = await Store.instance.importPhoto(shot);
    }
    if (path == null) return;
    setState(() => _busy.add(which));
    try {
      var photo = Photo(path, taken: DateTime.now().millisecondsSinceEpoch);
      // الأسنان بس: مطابقة تلقائية بزاويتي الفم حتى الصورتين بنفس الحجم.
      // التجميل بدون معايرة تلقائية: الصور تنحط مثل ما هي، والطبيب يحرّكها
      // بإصبعه أو يصوّر بالصورة الشبحية حتى تطلع مطابقة من الأساس.
      if (section == Section.dental) {
        try {
          photo = await _aligner.align(photo) ?? photo;
        } catch (_) {
          // بدون كشف الفم تبقى الصورة بضبط تلقائي عادي.
        }
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
    late final _Case saved;
    setState(() => saved = _remember(before, after));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeScreen.photos(
          before: before,
          after: after,
          templateId: saved.templateId,
          adjust: saved.adjust,
          flipped: saved.flipped,
          onLeave: (id, adjust, flipped) {
            final i = _cases.indexWhere((c) => c.after.path == after.path);
            if (i < 0) return;
            _cases[i] = _Case(
              before,
              after,
              DateTime.now(),
              templateId: id,
              adjust: adjust,
              flipped: flipped,
            );
            _saveCases();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
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
          children: _staggered([
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
                        'تصميم حالات قبل وبعد، ${ar(count)} قالب',
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
            const SizedBox(height: 18),
            _Steps(
              done: [
                _photos[Which.before] != null,
                _photos[Which.after] != null,
              ],
            ),
            const SizedBox(height: 14),
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
              child: Pressable(
                onTap: ready ? _design : null,
                child: Shine(
                  on: ready,
                  radius: BorderRadius.circular(20),
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
                  return GestureDetector(
                    onTap: () => showTemplateGallery(
                      context,
                      templates: templatesFor(b.section),
                    ),
                    child: ClipRRect(
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
                    ),
                  );
                },
              ),
            ),
            if (_cases.isNotEmpty) ...[
              const SizedBox(height: 26),
              Text(
                'حالات سابقة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: b.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اضغط حتى تصمم نفس الحالة بقالب ثاني، وطوّل الضغط للحذف.',
                style: TextStyle(color: b.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cases.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final c = _cases[i];
                    return GestureDetector(
                      onTap: () => setState(() {
                        _photos
                          ..clear()
                          ..[Which.after] = c.after;
                        if (c.before != null) _photos[Which.before] = c.before!;
                      }),
                      onLongPress: () => setState(() {
                        _cases.removeAt(i);
                        _saveCases();
                      }),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: c.before == null ? 84 : 150,
                          child: Row(
                            children: [
                              if (c.before != null)
                                Expanded(
                                  child: Image.file(
                                    File(c.before!.path),
                                    fit: BoxFit.cover,
                                    height: 112,
                                    cacheWidth: 200,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              Expanded(
                                child: Image.file(
                                  File(c.after.path),
                                  fit: BoxFit.cover,
                                  height: 112,
                                  cacheWidth: 200,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
          ]),
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
    return Pressable(
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
                Image.file(
                  File(p.path),
                  fit: BoxFit.cover,
                  cacheWidth: 500,
                  frameBuilder: (context, child, frame, sync) =>
                      AnimatedOpacity(
                        opacity: frame == null && !sync ? 0 : 1,
                        duration: const Duration(milliseconds: 380),
                        child: AnimatedScale(
                          scale: frame == null && !sync ? 1.06 : 1,
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutCubic,
                          child: child,
                        ),
                      ),
                )
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

class _Case {
  final Photo? before;
  final Photo after;
  final DateTime at;

  /// آخر قالب وتعديلات (حتى ترجع للحالة مثل ما تركتها).
  final String? templateId;
  final Map<Which, PhotoAdjust> adjust;
  final Set<Which> flipped;
  const _Case(
    this.before,
    this.after,
    this.at, {
    this.templateId,
    this.adjust = const {},
    this.flipped = const {},
  });

  Map<String, dynamic> toJson() => {
    if (before != null) 'before': before!.toJson(),
    'after': after.toJson(),
    'at': at.millisecondsSinceEpoch,
    if (templateId != null) 'template': templateId,
    if (adjust.isNotEmpty)
      'adjust': {for (final e in adjust.entries) e.key.name: e.value.toJson()},
    if (flipped.isNotEmpty) 'flip': [for (final w in flipped) w.name],
  };

  factory _Case.fromJson(Map<String, dynamic> j) => _Case(
    j['before'] == null
        ? null
        : Photo.fromJson(j['before'] as Map<String, dynamic>),
    Photo.fromJson(j['after'] as Map<String, dynamic>),
    DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    templateId: j['template'] as String?,
    adjust: {
      for (final e in ((j['adjust'] as Map?) ?? const {}).entries)
        Which.values.byName(e.key as String): PhotoAdjust.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    },
    flipped: {
      for (final n in (j['flip'] as List?) ?? const [])
        Which.values.byName(n as String),
    },
  );
}

/// ثلاث خطوات: صورة القبل، صورة البعد، التصميم.
class _Steps extends StatelessWidget {
  final List<bool> done;
  const _Steps({required this.done});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final ready = done.any((d) => d);
    final steps = [
      ('١', 'القبل', done[0]),
      ('٢', 'البعد', done[1]),
      ('٣', 'صمّم', false),
    ];
    return Row(
      children: [
        for (final (i, (n, label, ok)) in steps.indexed) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ok || (i == 2 && ready) ? b.action : null,
              color: ok || (i == 2 && ready) ? null : b.glass,
              border: Border.all(color: b.glassEdge),
            ),
            child: ok
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    n,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: i == 2 && ready ? Colors.white : b.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: ok ? b.text : b.muted,
            ),
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: ok ? b.primary : b.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
