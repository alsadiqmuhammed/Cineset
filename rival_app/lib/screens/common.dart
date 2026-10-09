import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../cloud.dart';
import '../main.dart';
import '../models.dart';
import '../sync.dart';

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String action = 'حذف',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// بطاقة بارزة بنفس لون الخلفية (Soft UI): ظل غامق تحت ولمعة فوق،
/// وتنضغط لجوه بنعومة وقت اللمس.
class BrandCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? topLine;
  final double radius;
  const BrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.topLine,
    this.radius = 22,
  });

  @override
  State<BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<BrandCard> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final r = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.color ?? b.glass,
          borderRadius: r,
          boxShadow: _down ? b.raised(0.35) : b.shadow,
          border: widget.topLine == null
              ? Border.all(color: b.glassEdge)
              : Border(top: BorderSide(color: widget.topLine!, width: 3)),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _set,
            splashColor: b.primary.withValues(alpha: 0.06),
            highlightColor: Colors.transparent,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// زر بارز (أيقونة وكلمة) ينضغط لجوه. للأزرار السريعة بالرئيسية.
class NeuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  /// لون أيقونة الزر (افتراضياً لون القسم).
  final Color? tint;
  const NeuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.tint,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final r = BorderRadius.circular(22);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: r,
            color: b.glass,
            border: Border.all(color: b.glassEdge),
            boxShadow: b.raised(_down ? 0.3 : 0.7),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: widget.accent ? b.action : null,
                  boxShadow: widget.accent ? b.actionShadow : null,
                  color: widget.accent
                      ? null
                      : (widget.tint ?? b.primary).withValues(
                          alpha: b.isDark ? 0.2 : 0.12,
                        ),
                ),
                child: Icon(
                  widget.icon,
                  size: 21,
                  color: widget.accent
                      ? Colors.white
                      : (b.isDark
                            ? Color.lerp(
                                widget.tint ?? b.primary,
                                Colors.white,
                                0.35,
                              )
                            : widget.tint ?? b.primaryDeep),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: b.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حلقة تقدّم تتعبى بنعومة وقت تظهر.
class AnimatedRing extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color color;
  final Color? color2;
  final Widget? child;
  const AnimatedRing({
    super.key,
    required this.value,
    required this.color,
    this.color2,
    this.size = 120,
    this.stroke = 10,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: b.pressed),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, color, color2 ?? color, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color a, b;
  final double stroke;
  const _RingPainter(this.v, this.a, this.b, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke,
    );
    if (v <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [a, b],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.a != a;
}

/// كرت غامق بتدرّج القسم مع حلقات ريڤال ونجوم اللمعة.
class HeroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      decoration: BoxDecoration(
        gradient: b.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: b.raised(0.9),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: RingsPainter(b.accent),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// حلقات ريڤال: دوائر رفيعة بزاوية التصميم، ونجوم لمعة صغيرة.
class RingsPainter extends CustomPainter {
  final Color color;
  const RingsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.06, size.height * 1.05);
    final r = math.max(size.width, size.height) * 0.42;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.22);
    canvas.drawCircle(c, r, line);
    canvas.drawCircle(c, r * 0.72, line);
    canvas.drawCircle(c, r * 0.86, line..color = color.withValues(alpha: 0.12));
    canvas.drawCircle(
      c + Offset.fromDirection(-0.9, r),
      3,
      Paint()..color = color.withValues(alpha: 0.6),
    );
    final star = Paint()..color = color.withValues(alpha: 0.85);
    sparkle(canvas, Offset(size.width * 0.9, size.height * 0.16), 7, star);
    sparkle(canvas, Offset(size.width * 0.84, size.height * 0.27), 3.5, star);
  }

  @override
  bool shouldRepaint(RingsPainter old) => old.color != color;
}

void sparkle(Canvas canvas, Offset c, double r, Paint paint) {
  final k = r * 0.22;
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close(),
    paint,
  );
}

/// شارة صغيرة (مثل "فريقنا" بالدليل).
class Pill extends StatelessWidget {
  final String text;
  final Color? bg, fg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.bg, this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final fore = fg ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? b.dark,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fore),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fore,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عنوان بسطرين: الأول غامق والثاني بلون القسم (مثل "خمسة أطباء / وابتسامة وحدة").
class TwoToneTitle extends StatelessWidget {
  final String first, second;
  final double size;
  final Color? firstColor, secondColor;
  const TwoToneTitle(
    this.first,
    this.second, {
    super.key,
    this.size = 26,
    this.firstColor,
    this.secondColor,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.25,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(first, style: style.copyWith(color: firstColor ?? b.text)),
        Text(
          second,
          style: b.feminine
              ? style.copyWith(
                  fontFamily: kFontAccent,
                  color: secondColor ?? b.highlight,
                  fontWeight: FontWeight.w700,
                )
              : style.copyWith(color: secondColor ?? b.primary),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: b.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: b.text,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: b.card,
                shape: BoxShape.circle,
                boxShadow: b.shadow,
              ),
              child: Icon(icon, size: 38, color: b.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: b.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: b.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoThumb extends StatelessWidget {
  final String? path;
  final String label;
  final double size;
  const PhotoThumb(this.path, this.label, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        color: b.line.withValues(alpha: 0.6),
        child: path == null
            ? Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: b.muted,
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) =>
                    Icon(Icons.broken_image_outlined, color: b.muted),
              ),
      ),
    );
  }
}

/// صورة الطبيب، أو أول حرف بدائرة بلون القسم (مثل الدليل).
class DoctorAvatar extends StatelessWidget {
  final Doctor? doctor;
  final double size;
  const DoctorAvatar(this.doctor, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final d = doctor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [b.primary, b.primaryDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: b.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: d?.photo != null
          ? Image.file(
              errorBuilder: missingPhoto,
              File(d!.photo!),
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
            )
          : Center(
              child: Text(
                d?.initial ?? '؟',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.42,
                ),
              ),
            ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final CaseStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final done = status == CaseStatus.done;
    return Pill(
      status.label,
      bg: done ? const Color(0xFFE3F1E6) : b.accent.withValues(alpha: 0.35),
      fg: done ? const Color(0xFF2E6B3B) : b.primaryDeep,
      icon: done ? Icons.check_circle : Icons.timelapse,
    );
  }
}

/// شريط أفقي للتقارير.
class BarRow extends StatelessWidget {
  final String label;
  final int value, max;
  final Color? color;

  /// كيف ينكتب الرقم (افتراضياً عدد بالعربي؛ للمبالغ [money]).
  final String Function(int)? format;
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.color,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final frac = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: b.text, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 14, color: b.line.withValues(alpha: 0.7)),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color ?? b.primary, b.primaryDeep],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: format == null ? 34 : 96,
            child: Text(
              format?.call(value) ?? ar(value),
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: b.text,
                fontSize: format == null ? null : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatDate(int ms) => arDate(ms);

/// يتخلص من حقول نافذة بعد ما تخلص حركة الإغلاق (قبلها النافذة بعدها ترسمها).
void disposeLater(List<ChangeNotifier> items) =>
    Future.delayed(const Duration(milliseconds: 600), () {
      for (final i in items) {
        i.dispose();
      }
    });

/// تبويبات ناعمة: مجرى غاطس والمختار بارز ينزلق بينها.
class NeuTabs extends StatelessWidget {
  final List<String> labels;
  final List<int>? badges;
  final int index;
  final ValueChanged<int> onChanged;
  const NeuTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final dir = Directionality.of(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: b.pressed,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / labels.length;
          final start = index * w;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                width: w,
                left: dir == TextDirection.rtl ? null : start,
                right: dir == TextDirection.rtl ? start : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: b.glass,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: b.raised(0.4),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontFamily: kFontUi,
                              fontSize: 12.5,
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: i == index ? b.primaryDeep : b.muted,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                                if ((badges?[i] ?? 0) > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 17,
                                    ),
                                    height: 17,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: i == index
                                          ? b.primary
                                          : b.muted.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      ar(badges![i]),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: i == index
                                            ? Colors.white
                                            : b.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// مكان صورة ما موجودة بعد (تنزل من جهاز ثاني) أو انحذفت.
Widget missingPhoto(BuildContext context, Object error, StackTrace? stack) {
  final b = context.brand;
  return Container(
    color: b.line.withValues(alpha: 0.5),
    alignment: Alignment.center,
    child: Icon(Icons.cloud_download_outlined, color: b.muted),
  );
}

/// مبدّل القسم بضغطة وحدة (أسنان / تجميل).
class SectionSwitch extends StatelessWidget {
  const SectionSwitch({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [ConnectionBadge(), SizedBox(width: 6), _SectionToggle()],
  );
}

/// أيقونة صغيرة بأعلى الشاشة: متصل ومتزامن، متصل، أو بدون إنترنت.
/// الضغط عليها يوضح الحالة.
class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Net.instance, Cloud.instance]),
      builder: (context, _) {
        final online = Net.instance.online;
        final cloud = Cloud.instance;
        final (icon, color, text) = !online
            ? (
                Icons.cloud_off,
                const Color(0xFF9E9E9E),
                'بدون إنترنت. تگدر تشتغل عادي، والتعديلات تنرفع لما يرجع الاتصال.',
              )
            : !cloud.signedIn
            ? (
                Icons.wifi,
                const Color(0xFF2E7D32),
                'متصل بالإنترنت. البيانات على هذا الجهاز بس (ما مسجل دخول بحساب العيادة).',
              )
            : switch (cloud.status) {
                SyncStatus.synced => (
                  Icons.cloud_done,
                  const Color(0xFF2E7D32),
                  'متصل ومتزامن ويا قاعدة بيانات العيادة.',
                ),
                SyncStatus.denied || SyncStatus.error => (
                  Icons.cloud_off,
                  const Color(0xFFC62828),
                  '${cloud.status.label}${cloud.detail == null ? '' : '\n${cloud.detail}'}',
                ),
                _ => (
                  Icons.cloud_sync,
                  const Color(0xFFF9A825),
                  'متصل، وجاري المزامنة ويا قاعدة بيانات العيادة...',
                ),
              };
        return Tooltip(
          message: text,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => toast(context, text),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        );
      },
    );
  }
}

/// مبدّل القسم بعرض الشاشة: مجرى غاطس والقسم المختار بارز بشعاره.
class SectionTabs extends StatelessWidget {
  const SectionTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    Widget seg(Brand x, String label) {
      final on = x.section == b.section;
      final tone = Brand.of(x.section, dark: b.isDark);
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on ? null : () => RivalApp.of(context).choose(x.section),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 42,
            decoration: BoxDecoration(
              color: on ? b.glass : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: on ? b.raised(0.4) : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: on ? 1 : 0.55,
                  child: Image.asset(x.symbol, height: 20),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                    color: on ? tone.primaryDeep : b.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: b.pressed,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [seg(dental, 'قسم الأسنان'), seg(beauty, 'قسم التجميل')],
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle();

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    Widget seg(Brand x, String label) {
      final on = x.section == b.section;
      final tone = Brand.of(x.section, dark: b.isDark);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: on ? tone.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: on ? b.raised(0.35) : const [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: on ? null : () => RivalApp.of(context).choose(x.section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  on ? x.logoReversed : x.symbol,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : b.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: b.pressed,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg(dental, 'أسنان'), seg(beauty, 'تجميل')],
      ),
    );
  }
}

/// رسمة لمّاعة ثلاثية الأبعاد: سن أبيض (أسنان) أو قطرة وردية (تجميل)،
/// ويا حلقة مدار ولمعات. للبطاقات الملونة وصفحة الدخول.
class GlossyEmblem extends StatelessWidget {
  final Section section;
  final double size;

  /// درع طبي صغير على السن (صفحة الدخول).
  final bool shield;

  /// على خلفية ملونة (الحلقة والظل بالأبيض).
  final bool onColor;
  const GlossyEmblem({
    super.key,
    required this.section,
    this.size = 120,
    this.shield = false,
    this.onColor = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 1.08,
    child: CustomPaint(painter: _GlossyPainter(section, shield, onColor)),
  );
}

class _GlossyPainter extends CustomPainter {
  final Section section;
  final bool shield, onColor;
  const _GlossyPainter(this.section, this.shield, this.onColor);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    Offset p(double x, double y) => Offset(x * w, y * w);
    final ring = onColor ? const Color(0x8CFFF6F0) : const Color(0xB3DBB686);
    // ظل تحت الرسمة.
    canvas.drawOval(
      Rect.fromCenter(center: p(0.5, 1.0), width: w * 0.55, height: w * 0.09),
      Paint()
        ..color = (onColor ? const Color(0xFF3C0A00) : const Color(0xFF785040))
            .withValues(alpha: onColor ? 0.3 : 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
    );
    // مدار خلفي.
    final orbit = Rect.fromCenter(
      center: p(0.5, 0.6),
      width: w * 0.98,
      height: w * 0.26,
    );
    canvas.drawArc(
      orbit,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = ring,
    );

    final body = Path();
    final Rect bounds;
    if (section == Section.dental) {
      body
        ..moveTo(p(0.5, 0.13).dx, p(0.5, 0.13).dy)
        ..cubicTo(
          p(0.62, 0.05).dx,
          p(0, 0.05).dy,
          p(0.83, 0.06).dx,
          p(0, 0.06).dy,
          p(0.85, 0.26).dx,
          p(0, 0.26).dy,
        )
        ..cubicTo(
          p(0.87, 0.42).dx,
          p(0, 0.42).dy,
          p(0.79, 0.53).dx,
          p(0, 0.53).dy,
          p(0.76, 0.66).dx,
          p(0, 0.66).dy,
        )
        ..cubicTo(
          p(0.73, 0.8).dx,
          p(0, 0.8).dy,
          p(0.71, 0.94).dx,
          p(0, 0.94).dy,
          p(0.64, 0.94).dx,
          p(0, 0.94).dy,
        )
        ..cubicTo(
          p(0.57, 0.94).dx,
          p(0, 0.94).dy,
          p(0.56, 0.77).dx,
          p(0, 0.77).dy,
          p(0.5, 0.71).dx,
          p(0, 0.71).dy,
        )
        ..cubicTo(
          p(0.44, 0.77).dx,
          p(0, 0.77).dy,
          p(0.43, 0.94).dx,
          p(0, 0.94).dy,
          p(0.36, 0.94).dx,
          p(0, 0.94).dy,
        )
        ..cubicTo(
          p(0.29, 0.94).dx,
          p(0, 0.94).dy,
          p(0.27, 0.8).dx,
          p(0, 0.8).dy,
          p(0.24, 0.66).dx,
          p(0, 0.66).dy,
        )
        ..cubicTo(
          p(0.21, 0.53).dx,
          p(0, 0.53).dy,
          p(0.13, 0.42).dx,
          p(0, 0.42).dy,
          p(0.15, 0.26).dx,
          p(0, 0.26).dy,
        )
        ..cubicTo(
          p(0.17, 0.06).dx,
          p(0, 0.06).dy,
          p(0.38, 0.05).dx,
          p(0, 0.05).dy,
          p(0.5, 0.13).dx,
          p(0, 0.13).dy,
        )
        ..close();
      bounds = body.getBounds();
      canvas.drawPath(
        body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.5),
            radius: 1.0,
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFFF8F2EB),
              Color(0xFFD9C7B5),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(bounds),
      );
    } else {
      body
        ..moveTo(p(0.5, 0.06).dx, p(0.5, 0.06).dy)
        ..cubicTo(
          p(0.62, 0.3).dx,
          p(0, 0.3).dy,
          p(0.8, 0.46).dx,
          p(0, 0.46).dy,
          p(0.8, 0.66).dx,
          p(0, 0.66).dy,
        )
        ..cubicTo(
          p(0.8, 0.84).dx,
          p(0, 0.84).dy,
          p(0.66, 0.96).dx,
          p(0, 0.96).dy,
          p(0.5, 0.96).dx,
          p(0, 0.96).dy,
        )
        ..cubicTo(
          p(0.34, 0.96).dx,
          p(0, 0.96).dy,
          p(0.2, 0.84).dx,
          p(0, 0.84).dy,
          p(0.2, 0.66).dx,
          p(0, 0.66).dy,
        )
        ..cubicTo(
          p(0.2, 0.46).dx,
          p(0, 0.46).dy,
          p(0.38, 0.3).dx,
          p(0, 0.3).dy,
          p(0.5, 0.06).dx,
          p(0, 0.06).dy,
        )
        ..close();
      bounds = body.getBounds();
      canvas.drawPath(
        body,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.1),
            radius: 0.95,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF8DCE2),
              Color(0xFFE7A9B6),
              Color(0xFFC77C8C),
            ],
            stops: [0, 0.3, 0.75, 1],
          ).createShader(bounds),
      );
    }
    // لمعة.
    canvas.drawPath(
      Path()
        ..moveTo(
          bounds.left + bounds.width * 0.18,
          bounds.top + bounds.height * (section == Section.dental ? 0.2 : 0.62),
        )
        ..quadraticBezierTo(
          bounds.left + bounds.width * 0.24,
          bounds.top +
              bounds.height * (section == Section.dental ? 0.08 : 0.42),
          bounds.left + bounds.width * 0.42,
          bounds.top +
              bounds.height * (section == Section.dental ? 0.08 : 0.28),
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.045
        ..color = const Color(0xE6FFFFFF),
    );
    // مدار أمامي.
    canvas.drawArc(
      orbit,
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = ring,
    );
    if (shield) {
      final c = p(0.78, 0.6);
      final r = w * 0.15;
      final sh = Path()
        ..moveTo(c.dx - r, c.dy - r * 0.75)
        ..lineTo(c.dx, c.dy - r * 1.05)
        ..lineTo(c.dx + r, c.dy - r * 0.75)
        ..lineTo(c.dx + r, c.dy + r * 0.05)
        ..quadraticBezierTo(c.dx + r, c.dy + r * 0.8, c.dx, c.dy + r * 1.1)
        ..quadraticBezierTo(c.dx - r, c.dy + r * 0.8, c.dx - r, c.dy + r * 0.05)
        ..close();
      canvas.drawPath(
        sh.shift(Offset(0, r * 0.12)),
        Paint()
          ..color = const Color(0x40500A00)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
      );
      canvas.drawPath(
        sh,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: section == Section.dental
                ? const [Color(0xFFE8573A), Color(0xFFA82E12)]
                : const [Color(0xFF9C3D4E), Color(0xFF5A0E1E)],
          ).createShader(sh.getBounds()),
      );
      final cross = Paint()..color = const Color(0xFFFFF6F0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: r * 0.28, height: r * 1.0),
          Radius.circular(r * 0.08),
        ),
        cross,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: r * 1.0, height: r * 0.28),
          Radius.circular(r * 0.08),
        ),
        cross,
      );
    }
    sparkle(
      canvas,
      p(0.92, 0.12),
      w * 0.05,
      Paint()
        ..color = onColor ? const Color(0xFFF3DCC0) : const Color(0xFFDBB686),
    );
    sparkle(
      canvas,
      p(0.08, 0.3),
      w * 0.03,
      Paint()
        ..color = onColor ? const Color(0xCCFFF6F0) : const Color(0xFFDBB686),
    );
  }

  @override
  bool shouldRepaint(_GlossyPainter old) =>
      old.section != section || old.shield != shield || old.onColor != onColor;
}
