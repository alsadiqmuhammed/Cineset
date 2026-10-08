import 'package:flutter/material.dart';

import '../brand.dart';
import '../charts.dart';

/// خريطة الأسنان على شكل القوسين بترقيم FDI، مثل ما يشوفها الطبيب مقابل المراجع.
class TeethChart extends StatefulWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final bool child;
  const TeethChart({
    super.key,
    required this.selected,
    required this.onToggle,
    this.child = false,
  });

  @override
  State<TeethChart> createState() => _TeethChartState();
}

class _TeethChartState extends State<TeethChart> {
  late bool _primary = widget.child || widget.selected.any(isPrimaryTooth);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final selected = widget.selected.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('دائمية')),
              ButtonSegment(value: true, label: Text('لبنية')),
            ],
            selected: {_primary},
            onSelectionChanged: (s) => setState(() => _primary = s.first),
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              return GestureDetector(
                onTapUp: (d) {
                  final t = toothAt(size, d.localPosition, primary: _primary);
                  if (t != null) widget.onToggle(t);
                },
                child: CustomPaint(
                  size: size,
                  painter: ToothChartPainter(
                    selected: widget.selected,
                    primary: _primary,
                    brand: b,
                  ),
                ),
              );
            },
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            teethSummary(selected),
            textAlign: TextAlign.center,
            style: TextStyle(color: b.primaryDeep, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final t in selected)
                InputChip(
                  label: Text(
                    '$t · ${toothName(t)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => widget.onToggle(t),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ] else
          Text(
            'اضغط على السن حتى تأشره',
            textAlign: TextAlign.center,
            style: TextStyle(color: b.muted, fontSize: 12),
          ),
      ],
    );
  }
}

/// خريطة الوجه: اضغط على المنطقة حتى تأشرها، ومرة ثانية حتى تكتب الكمية.
class FaceMap extends StatelessWidget {
  final List<String> selected;
  final Map<String, String> doses;
  final ValueChanged<String> onToggle;
  final void Function(String id, String dose) onDose;
  const FaceMap({
    super.key,
    required this.selected,
    required this.doses,
    required this.onToggle,
    required this.onDose,
  });

  Future<void> _editDose(BuildContext context, String id) async {
    final ctl = TextEditingController(text: doses[id]);
    final b = context.brand;
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(areaLabel(id)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'الكمية',
                hintText: 'مثلاً ٢٠ وحدة، ١ مل',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in [
                  '١٠ وحدة',
                  '٢٠ وحدة',
                  '٠.٥ مل',
                  '١ مل',
                  '٢ مل',
                ])
                  ActionChip(label: Text(s), onPressed: () => ctl.text = s),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onToggle(id);
            },
            child: Text('شيل المنطقة', style: TextStyle(color: b.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v != null) onDose(id, v);
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 300,
            child: AspectRatio(
              aspectRatio: 1 / faceAspect,
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = box.biggest;
                  return GestureDetector(
                    onTapUp: (d) {
                      final id = faceAreaAt(size, d.localPosition);
                      if (id == null) return;
                      selected.contains(id)
                          ? _editDose(context, id)
                          : onToggle(id);
                    },
                    child: CustomPaint(
                      size: size,
                      painter: FaceMapPainter(
                        selected: selected.toSet(),
                        doses: doses,
                        brand: b,
                        showDoses: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          selected.isEmpty
              ? 'اضغطي على المنطقة حتى تأشريها، واضغطي مرة ثانية حتى تكتبين الكمية'
              : 'اضغطي على المنطقة المؤشرة حتى تعدّلين الكمية',
          textAlign: TextAlign.center,
          style: TextStyle(color: b.muted, fontSize: 12),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final id in selected)
                InputChip(
                  label: Text(
                    (doses[id] ?? '').isEmpty
                        ? areaLabel(id)
                        : '${areaLabel(id)} · ${doses[id]}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _editDose(context, id),
                  onDeleted: () => onToggle(id),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
