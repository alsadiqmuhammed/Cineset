import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../store.dart';
import '../brand.dart';
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
    final b = context.brand;
    Widget tile(String? path) {
      final active = selected == path;
      return GestureDetector(
        onTap: () => onChanged(path),
        child: Container(
          width: 64,
          height: 80,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: b.line.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? b.primary : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: path == null
              ? Center(
                  child: Text('بدون', style: TextStyle(color: b.muted)),
                )
              : Image.file(File(path), fit: BoxFit.contain, cacheWidth: 200),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('القالب', style: TextStyle(color: b.muted)),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [tile(null), for (final o in overlays) tile(o)],
          ),
        ),
        if (overlays.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'ارفع قوالب PNG شفافة من "المزيد ← القوالب".',
              style: TextStyle(color: b.muted, fontSize: 12),
            ),
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
      await Gal.putVideo(path, album: Store.instance.brand.latinName);
    } else {
      await Gal.putImage(path, album: Store.instance.brand.latinName);
    }
    if (context.mounted) {
      toast(context, 'انحفظ بالمعرض (ألبوم ${Store.instance.brand.latinName})');
    }
  } on GalException catch (e) {
    if (context.mounted) toast(context, 'ما انحفظ: ${e.type.message}');
  }
}

Future<void> shareFile(String path) =>
    SharePlus.instance.share(ShareParams(files: [XFile(path)]));
