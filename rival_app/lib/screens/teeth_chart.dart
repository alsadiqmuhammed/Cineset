import 'package:flutter/material.dart';

import '../brand.dart';
import '../charts.dart';

/// خريطة الأسنان مرسومة (الفكين واللثة، ٣٢ مكان مع ضروس العقل)، مثل ما
/// يشوفها الطبيب مقابل المراجع. بدون أرقام. كل مكان يصير لبني أو دائمي،
/// والافتراضي حسب عمر المراجع.
class TeethChart extends StatefulWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  /// عمر المراجع (حتى يتحدد اللبني والدائمي تلقائياً).
  final int? age;

  /// الأماكن اللبنية اللي حددها الطبيب يدوياً (null = حسب العمر).
  final Set<int>? deciduous;

  /// يتغير لما الطبيب يقلب نوع سن: الأماكن اللبنية الجديدة، وnull يعني رجوع للعمر.
  final void Function(Set<int>? deciduous) onDeciduous;

  const TeethChart({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onDeciduous,
    this.age,
    this.deciduous,
  });

  @override
  State<TeethChart> createState() => _TeethChartState();
}

class _TeethChartState extends State<TeethChart> {
  bool _typeMode = false;

  Set<int> get _deciduous =>
      effectiveDeciduous(widget.deciduous, widget.age, widget.selected);

  void _tap(int pos) {
    final dec = _deciduous;
    if (!_typeMode) {
      widget.onToggle(dec.contains(pos) ? deciduousOf(pos)! : pos);
      return;
    }
    final baby = deciduousOf(pos);
    if (baby == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'الأضراس الدائمية (السادس والسابع والعقل) ما إلها لبني',
            ),
          ),
        );
      return;
    }
    final toBaby = !dec.contains(pos);
    // السن المؤشر يتحول وياه.
    final from = toBaby ? pos : baby, to = toBaby ? baby : pos;
    if (widget.selected.contains(from)) {
      widget.onToggle(from);
      widget.onToggle(to);
    }
    widget.onDeciduous(toBaby ? ({...dec}..add(pos)) : ({...dec}..remove(pos)));
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final selected = widget.selected.toList()..sort();
    final dec = _deciduous;
    final byAge = widget.deciduous == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('تأشير'),
                icon: Icon(Icons.touch_app_outlined, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('لبني ↔ دائمي'),
                icon: Icon(Icons.swap_horiz, size: 18),
              ),
            ],
            selected: {_typeMode},
            onSelectionChanged: (s) => setState(() => _typeMode = s.first),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _typeMode
              ? 'اضغط على السن حتى تقلبه لبني أو دائمي'
              : (widget.age == null
                    ? 'الأسنان دائمية. سجّل مواليد المراجع حتى تتحدد اللبنية تلقائياً'
                    : 'الأسنان حسب عمر المراجع (${ar(widget.age!)} سنة)${byAge ? '' : '، مع تعديلك'}'),
          textAlign: TextAlign.center,
          style: TextStyle(color: b.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 320,
            child: AspectRatio(
              aspectRatio: 1 / teethAspect,
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = box.biggest;
                  return GestureDetector(
                    onTapUp: (d) {
                      final t = toothAt(size, d.localPosition);
                      if (t != null) _tap(t);
                    },
                    child: CustomPaint(
                      size: size,
                      painter: ToothChartPainter(
                        selected: widget.selected,
                        deciduous: dec,
                        unerupted: uneruptedByAge(widget.age),
                        brand: b,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            _Legend(color: const Color(0xFFFFFDF8), label: 'دائمي', b: b),
            _Legend(color: const Color(0xFFF1DDB4), label: 'لبني', b: b),
            if (uneruptedByAge(widget.age).isNotEmpty)
              _Legend(
                color: const Color(0xFFFFFDF8),
                label: 'ما طالع بعد',
                b: b,
                faded: true,
              ),
            _Legend(color: b.primary, label: 'معالج', b: b),
            if (!byAge)
              TextButton.icon(
                onPressed: () => widget.onDeciduous(null),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('حسب العمر'),
              ),
          ],
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
                    toothName(t),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => widget.onToggle(t),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final Brand b;
  final bool faded;
  const _Legend({
    required this.color,
    required this.label,
    required this.b,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: faded ? 0.45 : 1,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9BDAA)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: b.muted, fontSize: 12)),
      ],
    ),
  );
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
