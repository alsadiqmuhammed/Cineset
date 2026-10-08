import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../brand.dart';
import '../models.dart';
import '../render.dart';
import '../store.dart';
import '../video.dart';
import 'common.dart';
import 'design_controls.dart';

const _videoSize = Size(1080, 1920);

class VideoScreen extends StatefulWidget {
  final CaseRecord record;
  const VideoScreen({super.key, required this.record});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  ui.Image? _before, _after, _overlay, _logo, _preview;
  late Framing _framing;
  String? _overlayPath;
  bool _labels = true;
  bool _brandFrame = true;
  bool _showAfter = false;
  bool _working = false;
  int _generation = 0;
  String? _video;
  VideoPlayerController? _player;

  Brand get _brand => Store.instance.brand;

  @override
  void initState() {
    super.initState();
    final offsetY = _brand.alignTarget == AlignTarget.eyes ? 0.06 : 0.0;
    _framing = Framing(offsetY: offsetY);
    () async {
      _before = await loadImage(widget.record.before!.path);
      _after = await loadImage(widget.record.after!.path);
      _logo = await loadAssetImage(_brand.logoReversed);
      var z = 1.0;
      for (final (img, photo) in [
        (_before!, widget.record.before!),
        (_after!, widget.record.after!),
      ]) {
        final size = Size(img.width.toDouble(), img.height.toDouble());
        z = math.max(
          z,
          coverZoom(Offset.zero & _videoSize, size, photo, offsetY),
        );
      }
      _framing = Framing(zoom: z.clamp(0.4, 2.5), offsetY: offsetY);
      _refresh();
    }();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  BrandFrame? get _frameSpec {
    if (!_brandFrame || _logo == null) return null;
    final d = Store.instance.doctor(widget.record.doctorId);
    return BrandFrame(
      _brand,
      _logo!,
      d == null ? _brand.name : '${d.name} · ${_brand.name}',
    );
  }

  /// إطار الصورة. بالمعاينة يجي ويه القالب والإطار؛ للفيديو يترسمون بطبقة ثابتة.
  Future<ui.Image> _frame(
    bool after, {
    double scale = 1,
    bool withLayers = true,
  }) => renderSingle(
    image: after ? _after! : _before!,
    photo: after ? widget.record.after! : widget.record.before!,
    size: _videoSize,
    framing: _framing,
    brand: _brand,
    after: after,
    label: _labels,
    framed: _brandFrame,
    overlay: withLayers ? _overlay : null,
    frame: withLayers ? _frameSpec : null,
    scale: scale,
  );

  Future<void> _refresh() async {
    if (_before == null) return;
    final gen = ++_generation;
    final img = await _frame(_showAfter, scale: 0.35);
    if (!mounted || gen != _generation) {
      img.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = img;
    });
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _player?.dispose();
      _player = null;
      _video = null;
    });
    _refresh();
  }

  Future<void> _setOverlay(String? path) async {
    _overlayPath = path;
    _overlay = path == null ? null : await loadImage(path);
    _update(() {});
  }

  Future<void> _make() async {
    setState(() => _working = true);
    final tmp = Store.instance.exportsDir.path;
    try {
      final b = await _frame(false, withLayers: false);
      final a = await _frame(true, withLayers: false);
      final bPath = await writePng(b, '$tmp/frame_before.png');
      final aPath = await writePng(a, '$tmp/frame_after.png');
      b.dispose();
      a.dispose();
      String? layerPath;
      if (_overlay != null || _frameSpec != null) {
        final o = await renderOverlayLayer(
          _videoSize,
          overlay: _overlay,
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

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final player = _player;
    return Scaffold(
      appBar: AppBar(title: const Text('فيديو التحوّل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: Container(
              height: 440,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: b.shadow,
              ),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: player != null
                      ? VideoPlayer(player)
                      : _preview == null
                      ? Container(
                          color: b.card,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : RawImage(image: _preview, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (player == null)
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('قبل')),
                  ButtonSegment(value: true, label: Text('بعد')),
                ],
                selected: {_showAfter},
                onSelectionChanged: (s) {
                  _showAfter = s.first;
                  _refresh();
                  setState(() {});
                },
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('إطار ${b.name}'),
                selected: _brandFrame,
                onSelected: (v) => _update(() => _brandFrame = v),
              ),
              FilterChip(
                label: const Text('كلمة قبل / بعد'),
                selected: _labels,
                onSelected: (v) => _update(() => _labels = v),
              ),
            ],
          ),
          FramingSliders(
            framing: _framing,
            onChanged: (f) => _update(() => _framing = f),
          ),
          OverlayPicker(selected: _overlayPath, onChanged: _setOverlay),
          const SizedBox(height: 20),
          if (_video == null)
            FilledButton.icon(
              onPressed: _preview == null || _working ? null : _make,
              icon: const Icon(Icons.movie_filter),
              label: Text(_working ? 'جاري الإنشاء...' : 'إنشاء الفيديو'),
            )
          else
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
          if (_working)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 12),
          Text(
            'فيديو عمودي ١٠٨٠×١٩٢٠، حوالي ٥ ثواني: يبدأ بـ"قبل" ويتحول تدريجياً لـ"بعد". جاهز للريلز والتيك توك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: b.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
