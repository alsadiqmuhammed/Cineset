import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../render.dart';
import '../store.dart';
import '../theme.dart';
import 'design_controls.dart';

class ComposeScreen extends StatefulWidget {
  final CaseRecord record;
  const ComposeScreen({super.key, required this.record});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  ui.Image? _before, _after, _overlay, _preview;
  PostFormat _format = PostFormat.portrait;
  Layout _layout = Layout.sideBySide;
  Framing _framing = const Framing();
  String? _overlayPath;
  bool _labels = true;
  bool _exporting = false;
  int _generation = 0;
  String? _exported;

  @override
  void initState() {
    super.initState();
    () async {
      _before = await loadImage(widget.record.before!.path);
      _after = await loadImage(widget.record.after!.path);
      _fitZoom();
      _refresh();
    }();
  }

  /// يختار تقريب يملأ الخليتين (ويبدأ من 1 على الأقل).
  void _fitZoom() {
    final cell = _layout == Layout.sideBySide
        ? Rect.fromLTWH(0, 0, _format.width / 2, _format.height.toDouble())
        : Rect.fromLTWH(0, 0, _format.width.toDouble(), _format.height / 2);
    var z = 1.0;
    for (final (img, photo) in [
      (_before!, widget.record.before!),
      (_after!, widget.record.after!),
    ]) {
      final size = Size(img.width.toDouble(), img.height.toDouble());
      z = math.max(z, coverZoom(cell, size, photo, _framing.offsetY));
    }
    _framing = Framing(zoom: z.clamp(0.4, 2.5), offsetY: _framing.offsetY);
  }

  CompositeSpec _spec() => CompositeSpec(
    before: _before!,
    after: _after!,
    beforePhoto: widget.record.before!,
    afterPhoto: widget.record.after!,
    format: _format,
    layout: _layout,
    framing: _framing,
    overlay: _overlay,
    labels: _labels,
  );

  /// يعيد رسم المعاينة؛ إذا تغيّر شي أثناء الرسم يتجاهل النتيجة القديمة.
  Future<void> _refresh() async {
    if (_before == null || _after == null) return;
    final gen = ++_generation;
    _exported = null;
    final img = await renderComposite(_spec(), scale: 0.4);
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
    setState(change);
    _refresh();
  }

  Future<void> _setOverlay(String? path) async {
    _overlayPath = path;
    _overlay = path == null ? null : await loadImage(path);
    _update(() {});
  }

  Future<String> _export() async {
    if (_exported != null) return _exported!;
    setState(() => _exporting = true);
    try {
      final img = await renderComposite(_spec());
      final path = await writePng(img, Store.instance.exportPath('png'));
      img.dispose();
      return _exported = path;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تصميم قبل وبعد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AspectRatio(
            aspectRatio: _format.width / _format.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _preview == null
                  ? Container(
                      color: kSurface,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : RawImage(image: _preview, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in PostFormat.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: _format == f,
                  onSelected: (_) => _update(() {
                    _format = f;
                    _fitZoom();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in Layout.values)
                ChoiceChip(
                  label: Text(l.label),
                  selected: _layout == l,
                  onSelected: (_) => _update(() {
                    _layout = l;
                    _fitZoom();
                  }),
                ),
              FilterChip(
                label: const Text('كلمة قبل / بعد'),
                selected: _labels,
                onSelected: (v) => _update(() => _labels = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FramingSliders(
            framing: _framing,
            onChanged: (f) => _update(() => _framing = f),
          ),
          OverlayPicker(selected: _overlayPath, onChanged: _setOverlay),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _preview == null || _exporting
                      ? null
                      : () async {
                          final path = await _export();
                          if (context.mounted) saveToGallery(context, path);
                        },
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
                  onPressed: _preview == null || _exporting
                      ? null
                      : () async => shareFile(await _export()),
                  icon: const Icon(Icons.share),
                  label: const Text('مشاركة'),
                ),
              ),
            ],
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
