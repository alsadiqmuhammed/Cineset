import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../render.dart';
import '../store.dart';
import '../theme.dart';
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
  ui.Image? _before, _after, _overlay, _preview;
  Framing _framing = const Framing();
  String? _overlayPath;
  bool _labels = true;
  bool _showAfter = false;
  bool _working = false;
  int _generation = 0;
  String? _video;
  VideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    () async {
      _before = await loadImage(widget.record.before!.path);
      _after = await loadImage(widget.record.after!.path);
      var z = 1.0;
      for (final (img, photo) in [
        (_before!, widget.record.before!),
        (_after!, widget.record.after!),
      ]) {
        final size = Size(img.width.toDouble(), img.height.toDouble());
        z = math.max(z, coverZoom(Offset.zero & _videoSize, size, photo, 0));
      }
      _framing = Framing(zoom: z.clamp(0.4, 2.5));
      _refresh();
    }();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<ui.Image> _frame(
    bool after, {
    double scale = 1,
    bool withOverlay = true,
  }) => renderSingle(
    image: after ? _after! : _before!,
    photo: after ? widget.record.after! : widget.record.before!,
    size: _videoSize,
    framing: _framing,
    overlay: withOverlay ? _overlay : null,
    label: _labels ? (after ? 'بعد' : 'قبل') : null,
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
      _resetVideo();
    });
    _refresh();
  }

  void _resetVideo() {
    _player?.dispose();
    _player = null;
    _video = null;
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
      final b = await _frame(false, withOverlay: false);
      final a = await _frame(true, withOverlay: false);
      final bPath = await writePng(b, '$tmp/frame_before.png');
      final aPath = await writePng(a, '$tmp/frame_after.png');
      b.dispose();
      a.dispose();
      String? overlayPath;
      if (_overlay != null) {
        final o = await renderOverlayLayer(_videoSize, _overlay!);
        overlayPath = await writePng(o, '$tmp/frame_overlay.png');
        o.dispose();
      }
      final out = await VideoMaker.make(
        beforeFrame: bPath,
        afterFrame: aPath,
        overlay: overlayPath,
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
    final player = _player;
    return Scaffold(
      appBar: AppBar(title: const Text('فيديو التحوّل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: SizedBox(
              height: 420,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: player != null
                      ? VideoPlayer(player)
                      : _preview == null
                      ? Container(
                          color: kSurface,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : RawImage(image: _preview, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('كلمة قبل / بعد'),
            selected: _labels,
            onSelected: (v) => _update(() => _labels = v),
          ),
          FramingSliders(
            framing: _framing,
            onChanged: (f) => _update(() => _framing = f),
          ),
          OverlayPicker(selected: _overlayPath, onChanged: _setOverlay),
          const SizedBox(height: 20),
          if (_video == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _preview == null || _working ? null : _make,
              icon: const Icon(Icons.movie_filter),
              label: Text(_working ? 'جاري الإنشاء...' : 'إنشاء الفيديو'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () =>
                        saveToGallery(context, _video!, video: true),
                    icon: const Icon(Icons.download),
                    label: const Text('حفظ بالمعرض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
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
          const Text(
            'فيديو عمودي 1080×1920، حوالي 5 ثواني: يبدأ بـ"قبل" ويتحول تدريجياً لـ"بعد". جاهز للريلز والتيك توك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
