import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';

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

/// كرت أبيض بظل دافي بثلاث طبقات ولمعة رفيعة فوق.
class BrandCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? topLine;
  const BrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.topLine,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: color ?? b.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: b.shadow,
        border: topLine == null
            ? null
            : Border(top: BorderSide(color: topLine!, width: 3)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
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
        boxShadow: b.shadow,
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
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.color,
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
            width: 34,
            child: Text(
              ar(value),
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.w800, color: b.text),
            ),
          ),
        ],
      ),
    );
  }
}

String formatDate(int ms) => arDate(ms);
