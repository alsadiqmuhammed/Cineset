import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../render.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// اختيار القالب الشفاف (PNG) فوق التصميم.
class OverlayPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const OverlayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final overlays = Store.instance.overlays;
    Widget tile(String? path) {
      final active = selected == path;
      return GestureDetector(
        onTap: () => onChanged(path),
        child: Container(
          width: 64,
          height: 80,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: kSurfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? kGold : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: path == null
              ? const Center(
                  child: Text('بدون', style: TextStyle(color: kMuted)),
                )
              : Image.file(File(path), fit: BoxFit.contain, cacheWidth: 200),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('القالب', style: TextStyle(color: kMuted)),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [tile(null), for (final o in overlays) tile(o)],
          ),
        ),
        if (overlays.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'ارفع قوالب PNG شفافة من تبويب "القوالب".',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class FramingSliders extends StatelessWidget {
  final Framing framing;
  final ValueChanged<Framing> onChanged;
  const FramingSliders({
    super.key,
    required this.framing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 70,
              child: Text('التقريب', style: TextStyle(color: kMuted)),
            ),
            Expanded(
              child: Slider(
                value: framing.zoom,
                min: 0.4,
                max: 2.5,
                onChanged: (v) =>
                    onChanged(Framing(zoom: v, offsetY: framing.offsetY)),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(
              width: 70,
              child: Text('الارتفاع', style: TextStyle(color: kMuted)),
            ),
            Expanded(
              child: Slider(
                value: framing.offsetY,
                min: -0.35,
                max: 0.35,
                onChanged: (v) =>
                    onChanged(Framing(zoom: framing.zoom, offsetY: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// يحفظ الملف بألبوم "Rival" بالمعرض.
Future<void> saveToGallery(
  BuildContext context,
  String path, {
  bool video = false,
}) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true)) {
      await Gal.requestAccess(toAlbum: true);
    }
    if (video) {
      await Gal.putVideo(path, album: 'Rival');
    } else {
      await Gal.putImage(path, album: 'Rival');
    }
    if (context.mounted) toast(context, 'انحفظ بالمعرض (ألبوم Rival)');
  } on GalException catch (e) {
    if (context.mounted) toast(context, 'ما انحفظ: ${e.type.message}');
  }
}

Future<void> shareFile(String path) =>
    SharePlus.instance.share(ShareParams(files: [XFile(path)]));
