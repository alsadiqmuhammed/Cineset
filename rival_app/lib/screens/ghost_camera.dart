import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';

/// طريقة إظهار صورة القبل فوق الكاميرا.
enum GhostMode {
  ghost('شبح', Icons.layers_outlined),
  split('نصفين', Icons.vertical_split_outlined),
  lines('خطوط', Icons.grid_on);

  final String label;
  final IconData icon;
  const GhostMode(this.label, this.icon);
}

/// كاميرا الصورة الشبحية: صورة القبل تبين شفافة فوق الكاميرا حتى تطابق
/// الزاوية والمسافة والإضاءة وقت تصوير البعد (مثل برامج العيادات الكبيرة).
/// ترجع مسار الصورة الملتقطة.
class GhostCamera extends StatefulWidget {
  final String title;

  /// صورة القبل (أو أي صورة مرجعية). بدونها الكاميرا بخطوط مساعدة بس.
  final String? ghost;
  final Section section;
  const GhostCamera({
    super.key,
    required this.title,
    required this.section,
    this.ghost,
  });

  @override
  State<GhostCamera> createState() => _GhostCameraState();
}

class _GhostCameraState extends State<GhostCamera>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _cam;
  int _index = 0;
  String? _error;
  late GhostMode _mode = widget.ghost == null
      ? GhostMode.lines
      : GhostMode.ghost;
  double _opacity = 0.42;
  double _split = 0.5;
  FlashMode _flash = FlashMode.off;
  bool _busy = false;
  XFile? _shot;
  late final _flashAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _flashAnim.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _cam = null;
    } else if (state == AppLifecycleState.resumed) {
      _open(_index);
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw CameraException('none', 'ماكو كاميرا');
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      await _open(back < 0 ? 0 : back);
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(CameraException e) => switch (e.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' =>
      'التطبيق يحتاج إذن الكاميرا. فعّله من إعدادات التلفون.',
    _ => 'ما اشتغلت الكاميرا: ${e.description ?? e.code}',
  };

  Future<void> _open(int i) async {
    final old = _cam;
    _cam = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(
      _cameras[i],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.setFlashMode(_flash);
      _index = i;
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
    } on CameraException catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || _busy || !c.value.isInitialized) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    _flashAnim.forward(from: 0);
    try {
      final f = await c.takePicture();
      if (mounted) setState(() => _shot = f);
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await _cam?.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(widget.section, dark: true);
    return Theme(
      data: b.theme(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _shot != null ? _review(b) : _live(b)),
        ),
      ),
    );
  }

  Widget _topBar(Brand b, {List<Widget> actions = const []}) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'إغلاق',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        Expanded(
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        ...actions,
        if (actions.isEmpty) const SizedBox(width: 48),
      ],
    ),
  );

  Widget _live(Brand b) {
    final c = _cam;
    final flashIcon = switch (_flash) {
      FlashMode.off => Icons.flash_off,
      FlashMode.auto => Icons.flash_auto,
      _ => Icons.flash_on,
    };
    return Column(
      children: [
        _topBar(
          b,
          actions: [
            IconButton(
              tooltip: 'الفلاش',
              onPressed: c == null ? null : _toggleFlash,
              icon: Icon(flashIcon, color: Colors.white),
            ),
          ],
        ),
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : c == null
              ? const Center(child: CircularProgressIndicator())
              : Center(child: _viewfinder(b, c)),
        ),
        _controls(b),
      ],
    );
  }

  Widget _viewfinder(Brand b, CameraController c) {
    // المعاينة بأندرويد بالعرض؛ بالطول النسبة معكوسة.
    final ratio = 1 / c.value.aspectRatio;
    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onHorizontalDragUpdate: _mode == GhostMode.split
              ? (d) => setState(
                  () => _split = (d.localPosition.dx / box.maxWidth).clamp(
                    0.05,
                    0.95,
                  ),
                )
              : null,
          onTapUp: (d) {
            final p = Offset(
              d.localPosition.dx / box.maxWidth,
              d.localPosition.dy / box.maxHeight,
            );
            c.setFocusPoint(p).catchError((_) {});
            c.setExposurePoint(p).catchError((_) {});
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CameraPreview(c),
              ),
              if (widget.ghost != null && _mode == GhostMode.ghost)
                IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Opacity(
                      opacity: _opacity,
                      child: Image.file(File(widget.ghost!), fit: BoxFit.cover),
                    ),
                  ),
                ),
              if (widget.ghost != null && _mode == GhostMode.split)
                IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ClipRect(
                      clipper: _RightOf(_split),
                      child: Image.file(File(widget.ghost!), fit: BoxFit.cover),
                    ),
                  ),
                ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _GuidePainter(
                      section: widget.section,
                      mode: _mode,
                      split: _split,
                      glow: _pulse.value,
                      accent: b.primary,
                    ),
                  ),
                ),
              ),
              if (widget.ghost != null && _mode == GhostMode.split)
                Positioned(
                  left: _split * box.maxWidth - 22,
                  top: box.maxHeight / 2 - 22,
                  child: IgnorePointer(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: FadeTransition(
                  opacity: ReverseAnimation(_flashAnim),
                  child: AnimatedBuilder(
                    animation: _flashAnim,
                    builder: (context, _) => _flashAnim.isAnimating
                        ? const ColoredBox(color: Colors.white)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(Brand b) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.ghost != null) ...[
          SegmentedButton<GhostMode>(
            showSelectedIcon: false,
            segments: [
              for (final m in GhostMode.values)
                ButtonSegment(
                  value: m,
                  icon: Icon(m.icon, size: 18),
                  label: Text(m.label),
                ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _mode == GhostMode.ghost
                ? Row(
                    children: [
                      const Icon(
                        Icons.opacity,
                        color: Colors.white70,
                        size: 18,
                      ),
                      Expanded(
                        child: Slider(
                          value: _opacity,
                          min: 0.1,
                          max: 0.85,
                          onChanged: (v) => setState(() => _opacity = v),
                        ),
                      ),
                      Text(
                        ar((_opacity * 100).round()),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _mode == GhostMode.split
                          ? 'اسحب الخط وطابق نص الوجه بالنص الثاني'
                          : 'خطوط مساعدة بدون صورة القبل',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'خلّي الوجه بالدليل، وصوّر بإضاءة ثابتة',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 52),
            GestureDetector(
              onTap: _shoot,
              child: AnimatedScale(
                scale: _busy ? 0.9 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: b.action,
                    ),
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              iconSize: 26,
              tooltip: 'قلب الكاميرا',
              onPressed: _cameras.length < 2 || _busy
                  ? null
                  : () => _open((_index + 1) % _cameras.length),
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _review(Brand b) => Column(
    children: [
      _topBar(b),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (widget.ghost != null) ...[
                Expanded(child: _thumb(widget.ghost!, 'قبل', Colors.black54)),
                const SizedBox(width: 8),
              ],
              Expanded(child: _thumb(_shot!.path, 'الجديدة', b.primary)),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _shot = null),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _shot!.path),
                icon: const Icon(Icons.check),
                label: const Text('استخدام'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _thumb(String path, String label, Color tag) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(path), fit: BoxFit.cover),
        PositionedDirectional(
          top: 10,
          start: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tag,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// يقص النص اليمين (صورة القبل باليمين مثل كل التصاميم).
class _RightOf extends CustomClipper<Rect> {
  final double x;
  const _RightOf(this.x);
  @override
  Rect getClip(Size s) => Rect.fromLTRB(s.width * x, 0, s.width, s.height);
  @override
  bool shouldReclip(_RightOf o) => o.x != x;
}

/// خطوط مساعدة: أثلاث، ودليل حسب القسم (خط الابتسامة للأسنان، بيضوي
/// الوجه للتجميل)، وخط النصفين.
class _GuidePainter extends CustomPainter {
  final Section section;
  final GhostMode mode;
  final double split, glow;
  final Color accent;
  _GuidePainter({
    required this.section,
    required this.mode,
    required this.split,
    required this.glow,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * f, 0),
        Offset(size.width * f, size.height),
        thin,
      );
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        thin,
      );
    }
    final guide = Paint()
      ..color = Color.lerp(Colors.white, accent, glow)!.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final c = size.center(Offset.zero);
    if (section == Section.dental) {
      // خط الابتسامة: قوس خفيف بالنص وخط الوسط العمودي.
      final w = size.width * 0.6;
      final path = Path()
        ..moveTo(c.dx - w / 2, c.dy - 8)
        ..quadraticBezierTo(
          c.dx,
          c.dy + size.height * 0.06,
          c.dx + w / 2,
          c.dy - 8,
        );
      canvas.drawPath(path, guide);
      _dash(
        canvas,
        Offset(c.dx, c.dy - size.height * 0.14),
        Offset(c.dx, c.dy + size.height * 0.14),
        guide,
      );
    } else {
      // بيضوي الوجه وخط العينين.
      final r = Rect.fromCenter(
        center: c,
        width: size.width * 0.62,
        height: size.height * 0.62,
      );
      canvas.drawOval(r, guide);
      _dash(
        canvas,
        Offset(r.left + 12, r.top + r.height * 0.42),
        Offset(r.right - 12, r.top + r.height * 0.42),
        guide,
      );
    }
    if (mode == GhostMode.split) {
      canvas.drawLine(
        Offset(size.width * split, 0),
        Offset(size.width * split, size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5,
      );
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = b - a;
    final n = (d.distance / 12).floor();
    for (var i = 0; i < n; i += 2) {
      canvas.drawLine(a + d * (i / n), a + d * (math.min(i + 1, n) / n), p);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter o) =>
      o.glow != glow || o.mode != mode || o.split != split;
}
