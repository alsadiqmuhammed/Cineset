import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../design.dart';
import '../models.dart';
import '../render.dart';
import '../store.dart';
import 'common.dart';
import 'adjust_panel.dart';
import 'template_gallery.dart';
import 'design_canvas.dart';
import 'design_controls.dart';
import 'elements_bar.dart';
import 'studio_controls.dart';

/// تصميم قبل وبعد: قوالب الهوية، تحريك الصور بالإصبع، وأدوات التضبيب والرسم.
class ComposeScreen extends StatefulWidget {
  final Patient? patient;

  /// صورة القبل اختيارية: بدونها تشتغل قوالب الصورة الوحدة بس.
  final Photo? before;
  final Photo after;
  final String? doctorId;

  ComposeScreen({super.key, this.patient, required CaseRecord record})
    : before = record.before,
      after = record.after!,
      doctorId = record.doctorId;

  /// تصميم من صور مختارة مباشرة (تطبيق ريڤال ستوديو).
  const ComposeScreen.photos({
    super.key,
    this.before,
    required this.after,
    this.doctorId,
  }) : patient = null;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _c = DesignController();
  final Map<Which, (ui.Image, Photo)> _photos = {};
  ui.Image? _logo, _templateImg, _overlay;
  late DesignTemplate? _template = _templates.first;
  PostFormat? _formatFilter;
  int? _photosFilter;
  bool _edgelessOnly = false;

  /// تحريك خط الدمج: مكانه، عرض الذوبان، واتجاهه.
  double _fadeShift = 0;
  double? _fadeWidth;
  FadeDir? _fadeDir;

  List<SlotMask?>? get _masks {
    final m = _template?.masks;
    if (m == null) return null;
    final dir = _template!.sameFrame ? _fadeDir : null;
    return [
      for (final x in m)
        x?.moved(shift: _fadeShift, width: _fadeWidth, dir: dir),
    ];
  }

  /// عرض الذوبان الأصلي بالقالب (حتى السلايدر يبدي منه).
  double get _baseWidth {
    for (final x in _template?.masks ?? const <SlotMask?>[]) {
      if (x != null && x.fades) return x.fadeEnd - x.fadeStart;
    }
    return 0.2;
  }

  PostFormat _format = PostFormat.portrait;
  Layout _layout = Layout.sideBySide;
  Which _single = Which.after;
  String? _overlayPath;
  bool _labels = true;
  bool _brandFrame = true;
  bool _exporting = false;
  bool _ready = false;
  Size? _lastSize;
  String? _exported;

  Brand get _brand => Store.instance.brand;

  bool get _hasBefore => widget.before != null;

  /// القوالب اللي تنفع للصور الموجودة.
  List<DesignTemplate> get _templates => [
    for (final t in templatesFor(_brand.section))
      if (_hasBefore || t.photos == 1) t,
  ];

  @override
  void initState() {
    super.initState();
    _c.addListener(() => _exported = null);
    () async {
      final before = widget.before, after = widget.after;
      try {
        if (before != null) {
          _photos[Which.before] = (await loadImage(before.path), before);
        }
        _photos[Which.after] = (await loadImage(after.path), after);
      } catch (e) {
        // صورة بعدها تنزل من جهاز ثاني أو انحذفت: نرجع برسالة بدل التحميل للأبد.
        if (!mounted) return;
        toast(context, '$e. جرب بعد شوية.');
        Navigator.pop(context);
        return;
      }
      _logo = await loadAssetImage(_brand.logoReversed);
      await _applyTemplate(_template);
      _addDoctorName();
    }();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Size get _size => _template?.format.size ?? _format.size;

  List<Rect> get _slots {
    final t = _template;
    if (t != null) return t.slots;
    final (first, second) = cellsFor(_format.size, _layout);
    // "قبل" باليمين (أو فوق).
    return _layout == Layout.sideBySide ? [second, first] : [first, second];
  }

  Framing get _base =>
      Framing(offsetY: _brand.alignTarget == AlignTarget.eyes ? -0.1 : 0);

  /// يرجّع الصور لوضعها التلقائي (تملأ الشبابيك ومتطابقة).
  void _fit() {
    final slots = _slots;
    final whiches = slots.length == 1 ? [_single] : [Which.before, Which.after];
    final old = _c.fills;
    final fills = <SlotFill>[];
    for (var i = 0; i < slots.length; i++) {
      final which = old.length == slots.length ? old[i].which : whiches[i];
      final p = _photos[which]!;
      fills.add(SlotFill(which, fitFraming(slots[i], p.$1, p.$2, _base)));
    }
    // الصورتين بنفس التقريب حتى تبقى المطابقة.
    if (fills.length == 2) {
      final z = math.max(fills[0].framing.zoom, fills[1].framing.zoom);
      for (final f in fills) {
        f.framing = f.framing.copyWith(zoom: z);
      }
    }
    _c.setFills(fills);
  }

  Future<void> _applyTemplate(DesignTemplate? t) async {
    _template = t;
    _fadeShift = 0;
    _fadeWidth = null;
    _fadeDir = null;
    _templateImg = t == null ? null : await loadAssetImage(t.asset);
    if (t != null) _labels = t.photos == 2 && !t.bakedLabels;
    _layoutChanged();
    if (mounted) setState(() => _ready = true);
  }

  /// تغيّر المقاس أو الشبابيك: نعيد الضبط، والإضافات تنمسح إذا تغيّر المقاس.
  void _layoutChanged() {
    if (_lastSize != null && _lastSize != _size) _c.clearMarks();
    _lastSize = _size;
    _c.fills = [];
    _fit();
    final name = _c.elementOf(ElementRole.doctor);
    if (name != null) _placeDoctorName(name);
  }

  Doctor? get _doctor =>
      widget.doctorId == null ? null : Store.instance.doctor(widget.doctorId);

  void _addDoctorName() {
    final d = _doctor;
    if (d == null || _c.elementOf(ElementRole.doctor) != null) return;
    final e = doctorNameElement(d.name, _brand);
    _placeDoctorName(e);
    _c.addElement(e);
    _c.select(null);
  }

  void _placeDoctorName(DesignElement e) {
    final spec = _spec();
    if (spec == null) return;
    placeAvoiding(
      e,
      _size,
      nameSpots(
        _size,
        _slots,
        templated: _template != null,
        framed: _brandFrame,
      ),
      spec.labelRects,
    );
  }

  DesignSpec? _spec() {
    if (!_ready || _c.fills.isEmpty) return null;
    final templated = _template != null;
    return DesignSpec(
      brand: _brand,
      size: _size,
      slots: _slots,
      fills: _c.fills,
      photos: _photos,
      template: _templateImg,
      overlay: templated ? null : _overlay,
      frame: !templated && _brandFrame && _logo != null
          ? BrandFrame(_brand, _logo!, '')
          : null,
      labels: _labels,
      labelsAtBottom: templated || _brandFrame,
      marks: _c.marks,
      elements: _c.elements,
      masks: _masks,
      labelAligns: _template?.labelAligns,
      background: _template?.background,
      backdrop: _template?.backdrop ?? false,
      adjust: Map.of(_c.adjust),
    );
  }

  Future<String> _export() async {
    if (_exported != null) return _exported!;
    setState(() => _exporting = true);
    try {
      final img = await renderDesign(_spec()!);
      final path = await writePng(img, Store.instance.exportPath('png'));
      img.dispose();
      return _exported = path;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// مقبض خط الدمج فوق المعاينة: تسحبه بإصبعك ويتحرك الدمج ويّاه.
  Widget? _seamHandle(double scale) {
    final t = _template, masks = _masks;
    if (t == null || masks == null) return null;
    for (var i = 0; i < masks.length && i < t.slots.length; i++) {
      final m = masks[i];
      final line = m?.seamIn(t.slots[i]);
      if (m == null || line == null) continue;
      final cell = t.slots[i];
      final dir = m.fadeTo!.withinRect(cell) - m.fadeFrom!.withinRect(cell);
      final pos = line.$1 * scale;
      const r = 21.0;
      return Positioned(
        left: pos.dx - r,
        top: pos.dy - r,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final dd = d.delta / scale;
            final k = (dd.dx * dir.dx + dd.dy * dir.dy) / dir.distanceSquared;
            setState(() => _fadeShift = (_fadeShift + k).clamp(-0.48, 0.48));
          },
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 10),
              ],
            ),
            child: Transform.rotate(
              angle: math.atan2(dir.dy, dir.dx),
              child: const Icon(
                Icons.swap_horiz,
                size: 22,
                color: Color(0xFF231F20),
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  /// نفس القالب بالمقاسات الثانية (بوست، ستوري، مربع).
  List<DesignTemplate> _siblings(DesignTemplate t) {
    final re = RegExp(r'_(post|story|square)(?=_|$)');
    String key(DesignTemplate x) => x.id.replaceAll(re, '_*');
    final k = key(t);
    return [
      for (final x in templatesFor(_brand.section))
        if (key(x) == k && x.photos == t.photos) x,
    ];
  }

  /// يصدّر التصميم بكل مقاسات القالب مرة وحدة ويحفظها بالمعرض.
  Future<void> _exportAllSizes() async {
    final t = _template!;
    final others = _siblings(t);
    if (_c.marks.isNotEmpty && others.length > 1) {
      // التضبيب والرسم مرسومين على هذا المقاس؛ بالمقاسات الثانية ما يطابقن
      // مكانهن، فما نصدّر تصميم ممكن يكشف شي مخفي.
      toast(
        context,
        'بالتصميم تضبيب أو رسم يخص هذا المقاس. صدّر كل مقاس لحاله.',
      );
      return;
    }
    setState(() => _exporting = true);
    final paths = <String>[];
    try {
      for (final x in others) {
        final DesignSpec spec;
        if (x.id == t.id) {
          spec = _spec()!;
        } else {
          final img = await loadAssetImage(x.asset);
          final fills = <SlotFill>[];
          for (var i = 0; i < x.slots.length && i < _c.fills.length; i++) {
            final which = _c.fills[i].which;
            final p = _photos[which]!;
            fills.add(
              SlotFill(which, fitFraming(x.slots[i], p.$1, p.$2, _base)),
            );
          }
          if (fills.length == 2) {
            final z = math.max(fills[0].framing.zoom, fills[1].framing.zoom);
            for (final f in fills) {
              f.framing = f.framing.copyWith(zoom: z);
            }
          }
          final dir = x.sameFrame ? _fadeDir : null;
          spec = DesignSpec(
            brand: _brand,
            size: x.format.size,
            slots: x.slots,
            fills: fills,
            photos: _photos,
            template: img,
            labels: _labels,
            labelsAtBottom: true,
            elements: _c.elements,
            masks: [
              for (final m in x.masks ?? const <SlotMask?>[])
                m?.moved(shift: _fadeShift, width: _fadeWidth, dir: dir),
            ],
            labelAligns: x.labelAligns,
            background: x.background,
            backdrop: x.backdrop,
            seam: x.seam,
            adjust: Map.of(_c.adjust),
          );
        }
        final out = await renderDesign(spec);
        paths.add(await writePng(out, Store.instance.exportPath('png')));
        out.dispose();
      }
      if (!mounted) return;
      for (final path in paths) {
        await saveToGallery(context, path);
      }
      if (mounted) toast(context, 'انحفظت ${ar(paths.length)} مقاسات بالمعرض');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _swap() {
    if (_c.fills.length != 2) return;
    final a = _c.fills[0].which;
    _c.fills[0].which = _c.fills[1].which;
    _c.fills[1].which = a;
    _fit();
  }

  FadeDir? _templateDir(DesignTemplate t) {
    for (final m in t.masks ?? const <SlotMask?>[]) {
      if (m == null || !m.fades) continue;
      for (final d in FadeDir.values) {
        if (d.ends == (m.fadeFrom, m.fadeTo)) return d;
      }
    }
    return null;
  }

  /// تبويب المحرر المفتوح.
  int _tab = 0;

  List<(IconData, String, String)> get _tabs => [
    (Icons.dashboard_customize_outlined, 'القوالب', 'templates'),
    (Icons.photo_outlined, 'الصور', 'photos'),
    (Icons.tune, 'الألوان', 'adjust'),
    if (_template?.blends ?? false) (Icons.gradient, 'الدمج', 'blend'),
    (Icons.brush_outlined, 'أدوات', 'tools'),
    (Icons.text_fields, 'نصوص', 'text'),
  ];

  void _openTab(int i) {
    // الخروج من الأدوات يرجّع التحريك حتى ما ترسم بالغلط.
    if (_tabs[_tab].$3 == 'tools' && i != _tab) _c.setTool(null);
    setState(() => _tab = i);
  }

  Widget _chip(
    String label,
    bool on,
    VoidCallback tap, {
    bool choice = false,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: choice
        ? ChoiceChip(
            label: Text(label),
            selected: on,
            onSelected: (_) => setState(tap),
          )
        : FilterChip(
            label: Text(label),
            selected: on,
            onSelected: (_) => setState(tap),
          ),
  );

  Widget _templatesPanel(Brand b, List<DesignTemplate> templates) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${ar(templates.length)} قالب',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: b.muted),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () async {
              final t = await showTemplateGallery(
                context,
                templates: _templates,
                selected: _template,
              );
              if (t != null) _applyTemplate(t);
            },
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('كل القوالب'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (label, f) in const [
              ('الكل', null),
              ('بوست', PostFormat.portrait),
              ('ستوري', PostFormat.story),
              ('مربع', PostFormat.square),
            ])
              _chip(
                label,
                _formatFilter == f,
                () => _formatFilter = f,
                choice: true,
              ),
            _chip(
              'بدون حواف',
              _edgelessOnly,
              () => _edgelessOnly = !_edgelessOnly,
            ),
            if (_hasBefore) ...[
              _chip(
                'صورتين',
                _photosFilter == 2,
                () => _photosFilter = _photosFilter == 2 ? null : 2,
              ),
              _chip(
                'صورة وحدة',
                _photosFilter == 1,
                () => _photosFilter = _photosFilter == 1 ? null : 1,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 116,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final t in templates)
              TemplateThumb(
                asset: t.asset,
                label: t.label,
                selected: _template?.id == t.id,
                onTap: () => _applyTemplate(t),
              ),
            if (_hasBefore)
              TemplateThumb(
                asset: null,
                label: 'بدون قالب',
                selected: _template == null,
                onTap: () => _applyTemplate(null),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _photosPanel(Brand b) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_slots.length == 1 && _hasBefore)
            for (final w in Which.values)
              ChoiceChip(
                label: Text('صورة ${w.label}'),
                selected: _single == w,
                onSelected: (_) {
                  setState(() => _single = w);
                  _c.fills = [];
                  _fit();
                },
              )
          else if (_slots.length == 2)
            ActionChip(
              avatar: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('بدّل مكان الصورتين'),
              onPressed: _swap,
            ),
          if (_hasBefore)
            FilterChip(
              label: const Text('كلمة قبل / بعد'),
              selected: _labels,
              onSelected: (v) => setState(() => _labels = v),
            ),
          ActionChip(
            avatar: const Icon(Icons.fit_screen, size: 18),
            label: const Text('ضبط تلقائي'),
            onPressed: _fit,
          ),
        ],
      ),
      if (_slots.length == 2)
        ListenableBuilder(
          listenable: _c,
          builder: (context, _) => SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _c.linked,
            onChanged: _c.setLinked,
            title: const Text('حرّك الصورتين سوا'),
          ),
        ),
      Text(
        'اسحب الصورة بإصبع، وكبّر أو دوّر بإصبعين.',
        style: TextStyle(color: b.muted, fontSize: 12),
      ),
      if (_template == null) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in PostFormat.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _format == f,
                onSelected: (_) => setState(() {
                  _format = f;
                  _layoutChanged();
                }),
              ),
            for (final l in Layout.values)
              ChoiceChip(
                label: Text(l.label),
                selected: _layout == l,
                onSelected: (_) => setState(() {
                  _layout = l;
                  _layoutChanged();
                }),
              ),
            FilterChip(
              label: Text('إطار ${b.name}'),
              selected: _brandFrame,
              onSelected: (v) => setState(() {
                _brandFrame = v;
                final name = _c.elementOf(ElementRole.doctor);
                if (name != null) _placeDoctorName(name);
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OverlayPicker(
          selected: _overlayPath,
          onChanged: (path) async {
            _overlayPath = path;
            _overlay = path == null ? null : await loadImage(path);
            setState(() {});
          },
        ),
      ],
    ],
  );

  Widget _blendPanel(Brand b) {
    final t = _template!;
    final width = _fadeWidth ?? _baseWidth;
    final edited = _fadeShift != 0 || _fadeWidth != null || _fadeDir != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: t.sameFrame
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final d in FadeDir.values)
                            _chip(
                              d.label,
                              (_fadeDir ?? _templateDir(t)) == d,
                              () => _fadeDir = d,
                              choice: true,
                            ),
                        ],
                      ),
                    )
                  : Text(
                      'اسحب المقبض فوق التصميم، أو حرّك المسطرة.',
                      style: TextStyle(color: b.muted, fontSize: 12),
                    ),
            ),
            IconButton(
              tooltip: 'إرجاع',
              onPressed: edited
                  ? () => setState(() {
                      _fadeShift = 0;
                      _fadeWidth = null;
                      _fadeDir = null;
                    })
                  : null,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        Text('مكان الخط', style: TextStyle(color: b.muted, fontSize: 12)),
        RulerSlider(
          value: _fadeShift,
          min: -0.48,
          max: 0.48,
          onChanged: (v) => setState(() => _fadeShift = v),
        ),
        Text('النعومة', style: TextStyle(color: b.muted, fontSize: 12)),
        RulerSlider(
          value: width.clamp(0.004, 0.9),
          min: 0.004,
          max: 0.9,
          reset: _baseWidth,
          format: (v) => '${ar((v * 100).round())}٪',
          onChanged: (v) => setState(() => _fadeWidth = v),
        ),
      ],
    );
  }

  /// ورقة الحفظ: معرض، مشاركة، كل المقاسات.
  Future<void> _exportSheet() async {
    final siblings = _template == null ? 1 : _siblings(_template!).length;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('حفظ بالمعرض'),
              onTap: () async {
                Navigator.pop(sheet);
                final path = await _export();
                if (mounted) saveToGallery(context, path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('مشاركة'),
              onTap: () async {
                Navigator.pop(sheet);
                shareFile(await _export());
              },
            ),
            if (siblings > 1)
              ListTile(
                leading: const Icon(Icons.burst_mode_outlined),
                title: const Text('كل المقاسات'),
                subtitle: Text(
                  'نفس التصميم بوست وستوري${siblings > 2 ? ' ومربع' : ''} مرة وحدة',
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  _exportAllSizes();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // المحرر دايماً غامق مثل برامج تعديل الصور: الألوان تبين على حقيقتها.
    return Theme(
      data: _brand.night.theme(),
      child: Builder(builder: _editor),
    );
  }

  Widget _editor(BuildContext context) {
    final b = context.brand;
    final templates = [
      for (final t in _templates)
        if ((_formatFilter == null || t.format == _formatFilter) &&
            (_photosFilter == null || t.photos == _photosFilter) &&
            (!_edgelessOnly || t.edgeless))
          t,
    ];
    final spec = _spec();
    final tabs = _tabs;
    if (_tab >= tabs.length) _tab = 0;
    final key = tabs[_tab].$3;
    final panel = switch (key) {
      'templates' => _templatesPanel(b, templates),
      'photos' => _photosPanel(b),
      'adjust' => AdjustPanel(
        controller: _c,
        photos: {for (final e in _photos.entries) e.key: e.value.$1},
      ),
      'blend' => _blendPanel(b),
      'tools' => DesignToolbar(
        controller: _c,
        twoPhotos: _slots.length == 2,
        onFit: _fit,
      ),
      _ => ListenableBuilder(
        listenable: _c,
        builder: (context, _) => ElementsBar(
          controller: _c,
          doctor: _doctor,
          onAddDoctorName: () => setState(_addDoctorName),
        ),
      ),
    };
    final ratio = _size.width / _size.height;
    return Scaffold(
      backgroundColor: b.bg,
      appBar: AppBar(
        backgroundColor: b.bg,
        title: Text(
          _template == null ? 'تصميم قبل وبعد' : templateFamily(_template!),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton.icon(
              onPressed: spec == null || _exporting ? null : _exportSheet,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share, size: 18),
              label: const Text('حفظ'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = math.min(
                  box.maxWidth - 32,
                  (box.maxHeight - 20) * ratio,
                );
                return Center(
                  child: Container(
                    width: w,
                    height: w / ratio,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: DesignCanvas(controller: _c, spec: _spec),
                        ),
                        ?_seamHandle(w / _size.width),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.36,
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: b.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: SingleChildScrollView(
                child: KeyedSubtree(key: ValueKey(key), child: panel),
              ),
            ),
          ),
          EditorTabs(
            items: [for (final t in tabs) (t.$1, t.$2)],
            index: _tab,
            onChanged: _openTab,
          ),
        ],
      ),
    );
  }
}
