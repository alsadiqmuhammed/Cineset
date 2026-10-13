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
import 'design_canvas.dart';
import 'design_controls.dart';
import 'elements_bar.dart';

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
      masks: _template?.masks,
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

  void _swap() {
    if (_c.fills.length != 2) return;
    final a = _c.fills[0].which;
    _c.fills[0].which = _c.fills[1].which;
    _c.fills[1].which = a;
    _fit();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final templates = [
      for (final t in _templates)
        if ((_formatFilter == null || t.format == _formatFilter) &&
            (_photosFilter == null || t.photos == _photosFilter) &&
            (!_edgelessOnly || t.edgeless))
          t,
    ];
    final spec = _spec();
    final screen = MediaQuery.of(context).size;
    final ratio = _size.width / _size.height;
    final width = math.min(screen.width - 32, screen.height * 0.44 * ratio);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصميم قبل وبعد'),
        actions: [
          IconButton(
            tooltip: 'مشاركة',
            onPressed: spec == null || _exporting
                ? null
                : () async => shareFile(await _export()),
            icon: const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'حفظ بالمعرض',
            onPressed: spec == null || _exporting
                ? null
                : () async {
                    final path = await _export();
                    if (context.mounted) saveToGallery(context, path);
                  },
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_exporting) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Center(
              child: Container(
                width: width,
                height: width / ratio,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: b.shadow,
                ),
                child: DesignCanvas(controller: _c, spec: _spec),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DesignToolbar(
              controller: _c,
              twoPhotos: _slots.length == 2,
              onFit: _fit,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: ListenableBuilder(
              listenable: _c,
              builder: (context, _) => _c.tool != null
                  ? const SizedBox.shrink()
                  : ElementsBar(
                      controller: _c,
                      doctor: _doctor,
                      onAddDoctorName: () => setState(_addDoctorName),
                    ),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    Text(
                      'القالب · ${ar(templates.length)}',
                      style: TextStyle(color: b.muted),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    runSpacing: 4,
                    children: [
                      for (final (label, f) in const [
                        ('الكل', null),
                        ('بوست', PostFormat.portrait),
                        ('ستوري', PostFormat.story),
                        ('مربع', PostFormat.square),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _formatFilter == f,
                            onSelected: (_) =>
                                setState(() => _formatFilter = f),
                          ),
                        ),
                      const SizedBox(width: 10),
                      FilterChip(
                        label: const Text('بدون حواف'),
                        selected: _edgelessOnly,
                        onSelected: (v) => setState(() => _edgelessOnly = v),
                      ),
                      if (_hasBefore) ...[
                        const SizedBox(width: 6),
                        for (final (label, n) in const [
                          ('صورتين', 2),
                          ('صورة وحدة', 1),
                        ])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: FilterChip(
                              label: Text(label),
                              selected: _photosFilter == n,
                              onSelected: (v) =>
                                  setState(() => _photosFilter = v ? n : null),
                            ),
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
                const SizedBox(height: 8),
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
                  ],
                ),
                const SizedBox(height: 14),
                AdjustPanel(
                  controller: _c,
                  photos: {for (final e in _photos.entries) e.key: e.value.$1},
                ),
                if (_template == null) ...[
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  OverlayPicker(
                    selected: _overlayPath,
                    onChanged: (path) async {
                      _overlayPath = path;
                      _overlay = path == null ? null : await loadImage(path);
                      setState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'النتائج تنشر بموافقة ${b.f('المراجع', 'المراجعة')}. استخدم التضبيب لإخفاء أي تفصيل خاص.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: b.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
