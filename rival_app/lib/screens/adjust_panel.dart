import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../design.dart';
import 'design_canvas.dart';

/// الإضاءة والألوان: لصورة القبل أو البعد أو الثنتين سوا، ويّا تحسين تلقائي.
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
  bool _open = false;
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
    setState(() => _working = true);
    try {
      for (final w in _targets) {
        final img = widget.photos[w];
        if (img != null) {
          widget.controller.setAdjust(w, await PhotoAdjust.auto(img));
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
        Widget slider(
          String label,
          IconData icon,
          double v,
          PhotoAdjust Function(PhotoAdjust, double) f,
        ) => Row(
          children: [
            Icon(icon, size: 18, color: b.muted),
            const SizedBox(width: 6),
            SizedBox(
              width: 64,
              child: Text(label, style: const TextStyle(fontSize: 12.5)),
            ),
            Expanded(
              child: Slider(
                value: v,
                min: -1,
                max: 1,
                onChanged: (x) => _set((p) => f(p, (x * 50).round() / 50)),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                ar((v * 100).round()),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11.5, color: b.muted),
              ),
            ),
          ],
        );
        return Material(
          color: b.glass,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: b.glassEdge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                dense: true,
                leading: Icon(Icons.tune, color: b.primary),
                title: const Text(
                  'الإضاءة والألوان',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: edited ? const Text('معدّلة') : null,
                trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _open = !_open),
              ),
              if (_open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (two)
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final (label, w) in [
                              ('الثنتين', null),
                              ('قبل', Which.before),
                              ('بعد', Which.after),
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: _target == w,
                                onSelected: (_) => setState(() => _target = w),
                              ),
                          ],
                        ),
                      slider(
                        'الإضاءة',
                        Icons.wb_sunny_outlined,
                        a.brightness,
                        (p, v) => p.copyWith(brightness: v),
                      ),
                      slider(
                        'التباين',
                        Icons.contrast,
                        a.contrast,
                        (p, v) => p.copyWith(contrast: v),
                      ),
                      slider(
                        'التشبّع',
                        Icons.palette_outlined,
                        a.saturation,
                        (p, v) => p.copyWith(saturation: v),
                      ),
                      slider(
                        'الدفء',
                        Icons.thermostat,
                        a.warmth,
                        (p, v) => p.copyWith(warmth: v),
                      ),
                      slider(
                        'الصبغة',
                        Icons.gradient,
                        a.tint,
                        (p, v) => p.copyWith(tint: v),
                      ),
                      slider(
                        'نعومة',
                        Icons.blur_linear,
                        a.fade,
                        (p, v) => p.copyWith(fade: v),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _working ? null : _auto,
                              icon: _working
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_fix_high, size: 18),
                              label: const Text('تحسين تلقائي'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: edited
                                ? () => _set((_) => PhotoAdjust.none)
                                : null,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('إرجاع'),
                          ),
                        ],
                      ),
                      Text(
                        'التعديل لتوضيح الصورة بس؛ ما يغيّر النتيجة الحقيقية للعلاج.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: b.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
