import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../brand.dart';
import '../design.dart';
import '../models.dart';
import '../render.dart';
import '../store.dart';
import '../video.dart';
import 'common.dart';
import 'design_canvas.dart';
import 'design_controls.dart';
import 'elements_bar.dart';

const _videoSize = Size(1080, 1920);

/// فيديو التحوّل: نفس المحرر (تحريك، تضبيب، رسم) وقالب الستوري أو إطار الهوية.
class VideoScreen extends StatefulWidget {
  final CaseRecord record;
  const VideoScreen({super.key, required this.record});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final _c = DesignController();
  final Map<Which, (ui.Image, Photo)> _photos = {};
  ui.Image? _logo, _templateImg, _overlay;
  late final DesignTemplate _story = templatesFor(_brand.section)
      .firstWhere((t) => t.format == PostFormat.story && t.photos == 1);
  bool _useTemplate = true;
  String? _overlayPath;
  bool _labels = true;
  bool _brandFrame = true;
  bool _working = false;
  double _progress = 0;
  String _stepText = '';
  String? _error;
  bool _ready = false;
  String? _video;
  VideoPlayerController? _player;

  Brand get _brand => Store.instance.brand;

  @override
  void initState() {
    super.initState();
    _c.addListener(_invalidate);
    () async {
      final r = widget.record;
      _photos[Which.before] = (await loadImage(r.before!.path), r.before!);
      _photos[Which.after] = (await loadImage(r.after!.path), r.after!);
      _logo = await loadAssetImage(_brand.logoReversed);
      _templateImg = await loadAssetImage(_story.asset);
      _fit();
      if (mounted) setState(() => _ready = true);
      _addDoctorName();
    }();
  }

  @override
  void dispose() {
    _player?.dispose();
    _c.dispose();
    super.dispose();
  }

  /// أي تعديل يلغي الفيديو القديم.
  void _invalidate() {
    if (_player == null) return;
    _player!.dispose();
    _player = null;
    _video = null;
    if (mounted) setState(() {});
  }

  Rect get _slot =>
      _useTemplate ? _story.slots.first : Offset.zero & _videoSize;

  void _fit() {
    final which = _c.fills.isEmpty ? Which.before : _c.fills.first.which;
    var f = Framing(offsetY: _brand.alignTarget == AlignTarget.eyes ? -0.1 : 0);
    // تقريب يملأ الشباك بالصورتين (الفيديو يتنقل بيناتهن).
    var z = 1.0;
    for (final p in _photos.values) {
      z = math.max(z, fitFraming(_slot, p.$1, p.$2, f).zoom);
    }
    f = f.copyWith(zoom: z);
    _c.setFills([SlotFill(which, f)]);
  }

  BrandFrame? get _frameSpec {
    if (_useTemplate || !_brandFrame || _logo == null) return null;
    return BrandFrame(_brand, _logo!, '');
  }

  Doctor? get _doctor => Store.instance.doctor(widget.record.doctorId);

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
      _videoSize,
      nameSpots(
        _videoSize,
        [_slot],
        templated: _useTemplate,
        framed: _brandFrame,
      ),
      spec.labelRects,
    );
  }

  void _replaceName() {
    final name = _c.elementOf(ElementRole.doctor);
    if (name != null) _placeDoctorName(name);
  }

  DesignSpec? _spec({Which? which, bool layers = true}) {
    if (!_ready || _c.fills.isEmpty) return null;
    final fill = _c.fills.first;
    return DesignSpec(
      brand: _brand,
      size: _videoSize,
      slots: [_slot],
      fills: which == null ? _c.fills : [SlotFill(which, fill.framing)],
      photos: _photos,
      template: layers && _useTemplate ? _templateImg : null,
      overlay: layers && !_useTemplate ? _overlay : null,
      frame: layers ? _frameSpec : null,
      labels: _labels,
      labelsAtBottom: _useTemplate || _brandFrame,
      marks: _c.marks,
      elements: layers ? _c.elements : const [],
    );
  }

  String get _logPath => '${Store.instance.exportsDir.path}/video_log.txt';

  void _step(String text, double progress) {
    if (!mounted) return;
    setState(() {
      _stepText = text;
      _progress = progress;
    });
  }

  Future<void> _make() async {
    setState(() {
      _working = true;
      _error = null;
    });
    final tmp = Store.instance.exportsDir.path;
    try {
      _step('تجهيز الصور...', 0.02);
      final b = await renderDesign(_spec(which: Which.before, layers: false)!);
      final a = await renderDesign(_spec(which: Which.after, layers: false)!);
      final bPath = await writePng(b, '$tmp/frame_before.png');
      _step('تجهيز الصور...', 0.06);
      final aPath = await writePng(a, '$tmp/frame_after.png');
      b.dispose();
      a.dispose();
      String? layerPath;
      final top = _useTemplate ? _templateImg : _overlay;
      if (top != null || _frameSpec != null || _c.elements.isNotEmpty) {
        final o = await renderOverlayLayer(
          _videoSize,
          overlay: top,
          frame: _frameSpec,
          elements: _c.elements,
        );
        layerPath = await writePng(o, '$tmp/frame_overlay.png');
        o.dispose();
      }
      _step('صناعة الفيديو...', 0.1);
      final out = await VideoMaker.make(
        beforeFrame: bPath,
        afterFrame: aPath,
        overlay: layerPath,
        output: Store.instance.exportPath('mp4'),
        log: _logPath,
        onProgress: (p) => _step('صناعة الفيديو...', 0.1 + 0.85 * p),
      );
      _step('تشغيل المعاينة...', 0.97);
      final player = VideoPlayerController.file(File(out));
      try {
        await player.initialize().timeout(const Duration(seconds: 20));
        await player.setLooping(true);
        await player.play();
      } catch (_) {
        // الفيديو انصنع؛ بس المعاينة ما اشتغلت. نخلّي الحفظ والمشاركة متاحة.
        player.dispose();
        if (mounted) {
          setState(() => _video = out);
          toast(
            context,
            'الفيديو جاهز. المعاينة ما اشتغلت، بس تگدر تحفظه أو تشاركه.',
          );
        }
        return;
      }
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _video = out;
        _player = player;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PlatformException ? (e.message ?? '$e') : '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _setState(VoidCallback f) {
    setState(f);
    _invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final player = _player;
    final screen = MediaQuery.of(context).size;
    final width = math.min(screen.width - 32, screen.height * 0.44 * 9 / 16);
    return Scaffold(
      appBar: AppBar(title: const Text('فيديو التحوّل')),
      body: Column(
        children: [
          if (_working) LinearProgressIndicator(value: _progress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Center(
              child: Container(
                width: width,
                height: width * 16 / 9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: b.shadow,
                ),
                child: player != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: VideoPlayer(player),
                      )
                    : DesignCanvas(controller: _c, spec: _spec),
              ),
            ),
          ),
          if (player == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DesignToolbar(
                controller: _c,
                twoPhotos: false,
                onFit: _fit,
              ),
            ),
          if (player == null)
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
                if (player == null && _c.fills.isNotEmpty)
                  Center(
                    child: SegmentedButton<Which>(
                      segments: [
                        for (final w in Which.values)
                          ButtonSegment(
                            value: w,
                            label: Text('معاينة ${w.label}'),
                          ),
                      ],
                      selected: {_c.fills.first.which},
                      onSelectionChanged: (s) {
                        _c.fills.first.which = s.first;
                        _c.changed();
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text('قالب ستوري ${b.name}'),
                      selected: _useTemplate,
                      onSelected: (v) => _setState(() {
                        _useTemplate = v;
                        _fit();
                        _replaceName();
                      }),
                    ),
                    if (!_useTemplate)
                      FilterChip(
                        label: Text('إطار ${b.name}'),
                        selected: _brandFrame,
                        onSelected: (v) => _setState(() {
                          _brandFrame = v;
                          _replaceName();
                        }),
                      ),
                    FilterChip(
                      label: const Text('كلمة قبل / بعد'),
                      selected: _labels,
                      onSelected: (v) => _setState(() {
                        _labels = v;
                        _replaceName();
                      }),
                    ),
                  ],
                ),
                if (!_useTemplate) ...[
                  const SizedBox(height: 12),
                  OverlayPicker(
                    selected: _overlayPath,
                    onChanged: (path) async {
                      _overlayPath = path;
                      _overlay = path == null ? null : await loadImage(path);
                      _setState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (_working)
                  Column(
                    children: [
                      Text(
                        '$_stepText ${ar((_progress * 100).round())}٪',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: b.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 10,
                        ),
                      ),
                    ],
                  )
                else if (_video == null) ...[
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ما انصنع الفيديو',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB3261E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(fontSize: 12)),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: () {
                                if (File(_logPath).existsSync()) {
                                  shareFile(_logPath);
                                }
                              },
                              icon: const Icon(Icons.bug_report_outlined),
                              label: const Text('شارك سجل الخطأ'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: !_ready ? null : _make,
                    icon: const Icon(Icons.movie_filter),
                    label: Text(
                      _error == null ? 'إنشاء الفيديو' : 'جرّب مرة ثانية',
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              saveToGallery(context, _video!, video: true),
                          icon: const Icon(Icons.download),
                          label: const Text('حفظ بالمعرض'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => shareFile(_video!),
                          icon: const Icon(Icons.share),
                          label: const Text('مشاركة'),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _setState(() {}),
                    icon: const Icon(Icons.edit),
                    label: const Text('رجوع للتعديل'),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'فيديو عمودي ١٠٨٠×١٩٢٠، حوالي ٥ ثواني: يبدأ بـ"قبل" ويتحول تدريجياً لـ"بعد". التضبيب والرسم يطلعون بالفيديو كامل.',
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
