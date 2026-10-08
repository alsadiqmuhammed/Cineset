import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
    final d = Store.instance.doctor(widget.record.doctorId);
    return BrandFrame(
      _brand,
      _logo!,
      d == null ? _brand.name : '${d.name} · ${_brand.name}',
    );
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
    );
  }

  Future<void> _make() async {
    setState(() => _working = true);
    final tmp = Store.instance.exportsDir.path;
    try {
      final b = await renderDesign(_spec(which: Which.before, layers: false)!);
      final a = await renderDesign(_spec(which: Which.after, layers: false)!);
      final bPath = await writePng(b, '$tmp/frame_before.png');
      final aPath = await writePng(a, '$tmp/frame_after.png');
      b.dispose();
      a.dispose();
      String? layerPath;
      final top = _useTemplate ? _templateImg : _overlay;
      if (top != null || _frameSpec != null) {
        final o = await renderOverlayLayer(
          _videoSize,
          overlay: top,
          frame: _frameSpec,
        );
        layerPath = await writePng(o, '$tmp/frame_overlay.png');
        o.dispose();
      }
      final out = await VideoMaker.make(
        beforeFrame: bPath,
        afterFrame: aPath,
        overlay: layerPath,
        output: Store.instance.exportPath('mp4'),
      );
      final player = VideoPlayerController.file(File(out));
      await player.initialize();
      await player.setLooping(true);
      await player.play();
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _video = out;
        _player = player;
      });
    } catch (e) {
      if (mounted) toast(context, 'صار خطأ بإنشاء الفيديو: $e');
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
          if (_working) const LinearProgressIndicator(),
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
                      }),
                    ),
                    if (!_useTemplate)
                      FilterChip(
                        label: Text('إطار ${b.name}'),
                        selected: _brandFrame,
                        onSelected: (v) => _setState(() => _brandFrame = v),
                      ),
                    FilterChip(
                      label: const Text('كلمة قبل / بعد'),
                      selected: _labels,
                      onSelected: (v) => _setState(() => _labels = v),
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
                if (_video == null)
                  FilledButton.icon(
                    onPressed: !_ready || _working ? null : _make,
                    icon: const Icon(Icons.movie_filter),
                    label: Text(_working ? 'جاري الإنشاء...' : 'إنشاء الفيديو'),
                  )
                else ...[
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
