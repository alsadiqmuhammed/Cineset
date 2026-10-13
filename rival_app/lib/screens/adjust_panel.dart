import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../design.dart';
import 'design_canvas.dart';
import 'studio_controls.dart';

enum _Knob {
  brightness('الإضاءة', Icons.wb_sunny_outlined),
  contrast('التباين', Icons.contrast),
  saturation('التشبّع', Icons.palette_outlined),
  warmth('الدفء', Icons.thermostat),
  tint('الصبغة', Icons.gradient),
  fade('نعومة', Icons.blur_linear);

  final String label;
  final IconData icon;
  const _Knob(this.label, this.icon);

  double of(PhotoAdjust a) => switch (this) {
    _Knob.brightness => a.brightness,
    _Knob.contrast => a.contrast,
    _Knob.saturation => a.saturation,
    _Knob.warmth => a.warmth,
    _Knob.tint => a.tint,
    _Knob.fade => a.fade,
  };

  PhotoAdjust set(PhotoAdjust a, double v) => switch (this) {
    _Knob.brightness => a.copyWith(brightness: v),
    _Knob.contrast => a.copyWith(contrast: v),
    _Knob.saturation => a.copyWith(saturation: v),
    _Knob.warmth => a.copyWith(warmth: v),
    _Knob.tint => a.copyWith(tint: v),
    _Knob.fade => a.copyWith(fade: v),
  };
}

/// الإضاءة والألوان مثل برامج تعديل الصور: أقراص تختار التعديل، ومسطرة
/// تحرّكه. لصورة القبل أو البعد أو الثنتين سوا، ويّا تحسين تلقائي.
class AdjustPanel extends StatefulWidget {
  final DesignController controller;
  final Map<Which, ui.Image> photos;
  const AdjustPanel({
    super.key,
    required this.controller,
    required this.photos,
  });

  @override
  State<AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends State<AdjustPanel> {
  /// null = الثنتين سوا.
  Which? _target;
  _Knob _knob = _Knob.brightness;
  bool _working = false;

  List<Which> get _targets =>
      _target == null ? widget.photos.keys.toList() : [_target!];

  PhotoAdjust get _current =>
      widget.controller.adjust[_targets.isEmpty
          ? Which.after
          : _targets.first] ??
      PhotoAdjust.none;

  void _set(PhotoAdjust Function(PhotoAdjust) f) {
    for (final w in _targets) {
      widget.controller.setAdjust(
        w,
        f(widget.controller.adjust[w] ?? PhotoAdjust.none),
      );
    }
  }

  Future<void> _auto() async {
    final beauty = context.brand.section == Section.beauty;
    setState(() => _working = true);
    try {
      for (final w in _targets) {
        final img = widget.photos[w];
        if (img != null) {
          widget.controller.setAdjust(
            w,
            await PhotoAdjust.auto(img, beauty: beauty),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final two = widget.photos.length == 2;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final a = _current;
        final edited = widget.controller.adjust.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (two)
                  Expanded(
                    child: SegmentedButton<Which?>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: null, label: Text('الثنتين')),
                        ButtonSegment(value: Which.before, label: Text('قبل')),
                        ButtonSegment(value: Which.after, label: Text('بعد')),
                      ],
                      selected: {_target},
                      onSelectionChanged: (s) =>
                          setState(() => _target = s.first),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'تحسين تلقائي',
                  onPressed: _working ? null : _auto,
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                ),
                IconButton(
                  tooltip: 'إرجاع',
                  onPressed: edited
                      ? () => _set((_) => PhotoAdjust.none)
                      : null,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in _Knob.values)
                    ValueDial(
                      icon: k.icon,
                      label: k.label,
                      value: k.of(a),
                      selected: _knob == k,
                      onTap: () => setState(() => _knob = k),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            RulerSlider(
              value: _knob.of(a),
              onChanged: (v) =>
                  _set((p) => _knob.set(p, (v * 100).round() / 100)),
            ),
            Text(
              'التعديل لتوضيح الصورة بس؛ ما يغيّر النتيجة الحقيقية للعلاج.',
              textAlign: TextAlign.center,
              style: TextStyle(color: b.muted, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
