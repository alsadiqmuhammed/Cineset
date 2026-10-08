import 'package:flutter/material.dart';

import '../brand.dart';
import '../design.dart';
import '../render.dart';

/// حالة المحرر: الأداة، الإضافات (مع تراجع/إعادة)، ومكان الصور بالشبابيك.
class DesignController extends ChangeNotifier {
  /// null = تحريك الصور.
  MarkKind? tool;
  Color color = const Color(0xFFFFFFFF);
  double width = 0.006;
  bool linked = true;
  List<SlotFill> fills = [];
  final List<Mark> marks = [];
  final List<Mark> _redo = [];

  /// نصوص وصور فوق التصميم، والمحدد حالياً.
  final List<DesignElement> elements = [];
  DesignElement? selected;

  void addElement(DesignElement e) {
    elements.add(e);
    selected = e;
    tool = null;
    notifyListeners();
  }

  void removeElement(DesignElement e) {
    elements.remove(e);
    if (selected == e) selected = null;
    notifyListeners();
  }

  void select(DesignElement? e) {
    if (selected == e) return;
    selected = e;
    notifyListeners();
  }

  DesignElement? elementOf(ElementRole role) {
    for (final e in elements) {
      if (e.role == role) return e;
    }
    return null;
  }

  bool get canUndo => marks.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void setTool(MarkKind? t) {
    tool = t;
    if (t != null) selected = null;
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  void setLinked(bool v) {
    linked = v;
    notifyListeners();
  }

  void undo() {
    if (marks.isEmpty) return;
    _redo.add(marks.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    marks.add(_redo.removeLast());
    notifyListeners();
  }

  void clearMarks() {
    marks.clear();
    _redo.clear();
    notifyListeners();
  }

  void setFills(List<SlotFill> f) {
    fills = f;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

/// المعاينة الحيّة للتصميم. تحريك: إصبع يحرّك، إصبعين للتكبير والتدوير.
/// باقي الأدوات ترسم بإصبع واحد.
class DesignCanvas extends StatefulWidget {
  final DesignController controller;
  final DesignSpec? Function() spec;
  const DesignCanvas({super.key, required this.controller, required this.spec});

  @override
  State<DesignCanvas> createState() => _DesignCanvasState();
}

class _DesignCanvasState extends State<DesignCanvas> {
  DesignController get c => widget.controller;
  double _k = 1; // بكسلات التصميم لكل بكسل شاشة
  Offset _startFocal = Offset.zero;
  List<Framing> _start = [];
  List<int> _moving = [];
  Mark? _current;
  DesignElement? _elem;
  (Offset, double, double) _elemStart = (Offset.zero, 1, 0);

  Offset _toDesign(Offset local) => local * _k;

  int _slotAt(DesignSpec s, Offset p) {
    for (var i = 0; i < s.slots.length; i++) {
      if (s.slots[i].contains(p)) return i;
    }
    var best = 0;
    var dist = double.infinity;
    for (var i = 0; i < s.slots.length; i++) {
      final d = (s.slots[i].center - p).distance;
      if (d < dist) {
        dist = d;
        best = i;
      }
    }
    return best;
  }

  void _onStart(ScaleStartDetails d) {
    final s = widget.spec();
    if (s == null) return;
    final p = _toDesign(d.localFocalPoint);
    if (c.tool == null) {
      // العنصر (نص/صورة) يتحرك بإصبع، ويكبر ويتدور بإصبعين.
      final e =
          c.selected != null &&
              c.selected!.hit(s.size, p, slop: s.size.width * 0.04)
          ? c.selected
          : elementAt(c.elements, s.size, p);
      _elem = e;
      c.select(e);
      if (e != null) {
        _elemStart = (e.center, e.size, e.rotation);
        _startFocal = p;
        return;
      }
      final i = _slotAt(s, p);
      _moving = c.linked ? [for (var j = 0; j < c.fills.length; j++) j] : [i];
      _start = [for (final f in c.fills) f.framing];
      _startFocal = p;
      return;
    }
    if (d.pointerCount > 1) return;
    _current = Mark(c.tool!, [p], c.color, c.width);
    c.marks.add(_current!);
    c._redo.clear();
    c.changed();
  }

  void _onUpdate(ScaleUpdateDetails d) {
    final s = widget.spec();
    if (s == null) return;
    final p = _toDesign(d.localFocalPoint);
    if (c.tool == null && _elem != null) {
      final e = _elem!;
      final delta = p - _startFocal;
      final (center, size, rotation) = _elemStart;
      e.center = Offset(
        (center.dx + delta.dx / s.size.width).clamp(0.0, 1.0),
        (center.dy + delta.dy / s.size.height).clamp(0.0, 1.0),
      );
      e.size = e.isText
          ? (size * d.scale).clamp(0.012, 0.25)
          : (size * d.scale).clamp(0.04, 1.2);
      e.rotation = rotation + d.rotation;
      c.changed();
      return;
    }
    if (c.tool == null) {
      final delta = p - _startFocal;
      for (final i in _moving) {
        if (i >= c.fills.length || i >= s.slots.length) continue;
        final cell = s.slots[i];
        final f0 = _start[i];
        c.fills[i].framing = Framing(
          zoom: (f0.zoom * d.scale).clamp(0.3, 6.0),
          offsetX: f0.offsetX + delta.dx / cell.width,
          offsetY: f0.offsetY + delta.dy / cell.height,
          rotation: f0.rotation + d.rotation,
        );
      }
      c.changed();
      return;
    }
    final m = _current;
    if (m == null) return;
    if (m.kind.freehand) {
      if ((m.points.last - p).distance > 2) m.points.add(p);
    } else {
      if (m.points.length == 1) {
        m.points.add(p);
      } else {
        m.points[1] = p;
      }
    }
    c.changed();
  }

  void _onEnd(ScaleEndDetails d) {
    _elem = null;
    final m = _current;
    _current = null;
    if (m == null) return;
    // شكل بدون سحب (نقرة) ما إله معنى.
    if (!m.kind.freehand &&
        (m.points.length < 2 || (m.points[0] - m.points[1]).distance < 6)) {
      c.marks.remove(m);
      c.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final s = widget.spec();
        if (s == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final w = box.maxWidth;
        final h = w * s.size.height / s.size.width;
        _k = s.size.width / w;
        return SizedBox(
          width: w,
          height: h,
          child: GestureDetector(
            onScaleStart: _onStart,
            onScaleUpdate: _onUpdate,
            onScaleEnd: _onEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                size: Size(w, h),
                painter: _DesignPainter(c, widget.spec),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesignPainter extends CustomPainter {
  final DesignController c;
  final DesignSpec? Function() spec;
  _DesignPainter(this.c, this.spec) : super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = spec();
    if (s == null) return;
    canvas.save();
    canvas.scale(size.width / s.size.width);
    paintDesign(canvas, s);
    final sel = c.selected;
    if (sel != null && s.elements.contains(sel)) {
      sel.paintSelection(canvas, s.size, s.brand.accent);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DesignPainter old) => true;
}

/// شريط الأدوات تحت المعاينة.
class DesignToolbar extends StatelessWidget {
  final DesignController controller;
  final VoidCallback onFit;
  final bool twoPhotos;
  const DesignToolbar({
    super.key,
    required this.controller,
    required this.onFit,
    required this.twoPhotos,
  });

  static const _icons = {
    MarkKind.pen: Icons.brush_outlined,
    MarkKind.arrow: Icons.north_east,
    MarkKind.circle: Icons.circle_outlined,
    MarkKind.rect: Icons.crop_square,
    MarkKind.blurRect: Icons.blur_on,
    MarkKind.blurBrush: Icons.blur_circular,
    MarkKind.eraser: Icons.cleaning_services_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final c = controller;
    final colors = [
      Colors.white,
      b.primary,
      b.accent,
      b.dark,
      const Color(0xFFE53935),
      const Color(0xFF2E7D32),
      const Color(0xFFFFD54F),
    ];
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget tool(MarkKind? k, IconData icon, String label) {
          final on = c.tool == k;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Material(
              color: on ? b.primary : b.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => c.setTool(k),
                child: Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: on ? b.primary : b.line),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, size: 20, color: on ? Colors.white : b.text),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : b.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final drawing =
            c.tool != null &&
            c.tool != MarkKind.blurRect &&
            c.tool != MarkKind.blurBrush &&
            c.tool != MarkKind.eraser;
        final sized = c.tool != null && c.tool != MarkKind.blurRect;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 62,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  tool(null, Icons.open_with, 'تحريك'),
                  for (final k in MarkKind.values) tool(k, _icons[k]!, k.label),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (c.tool == null)
              Row(
                children: [
                  if (twoPhotos)
                    Expanded(
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: c.linked,
                        onChanged: c.setLinked,
                        title: const Text(
                          'حرّك الصورتين سوا',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        'اسحب بإصبع، وكبّر أو دوّر بإصبعين',
                        style: TextStyle(color: b.muted, fontSize: 12),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onFit,
                    icon: const Icon(Icons.fit_screen, size: 18),
                    label: const Text('ضبط تلقائي'),
                  ),
                ],
              )
            else ...[
              if (drawing)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final col in colors)
                        GestureDetector(
                          onTap: () => c.setColor(col),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsetsDirectional.only(end: 8),
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.color == col ? b.primary : b.line,
                                width: c.color == col ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  if (sized) ...[
                    Icon(Icons.line_weight, size: 18, color: b.muted),
                    Expanded(
                      child: Slider(
                        value: c.width,
                        min: 0.002,
                        max: 0.02,
                        onChanged: c.setWidth,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'اسحب على المنطقة اللي تريد تضببها',
                        style: TextStyle(color: b.muted, fontSize: 12),
                      ),
                    ),
                  IconButton(
                    tooltip: 'تراجع',
                    onPressed: c.canUndo ? c.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'إعادة',
                    onPressed: c.canRedo ? c.redo : null,
                    icon: const Icon(Icons.redo),
                  ),
                  IconButton(
                    tooltip: 'مسح كل الإضافات',
                    onPressed: c.marks.isEmpty ? null : c.clearMarks,
                    icon: const Icon(Icons.layers_clear_outlined),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// معاينة صغيرة للقالب (للاختيار).
class TemplateThumb extends StatelessWidget {
  final String? asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const TemplateThumb({
    super.key,
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        margin: const EdgeInsetsDirectional.only(end: 8),
        child: Column(
          children: [
            Container(
              height: 92,
              decoration: BoxDecoration(
                color: b.line.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? b.primary : b.line,
                  width: selected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: asset == null
                  ? Center(
                      child: Icon(Icons.view_column_outlined, color: b.muted),
                    )
                  : Image.asset(asset!, fit: BoxFit.contain, cacheWidth: 200),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: selected ? b.primaryDeep : b.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
