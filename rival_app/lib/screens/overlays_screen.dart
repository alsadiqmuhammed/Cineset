import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../render.dart';
import '../store.dart';
import '../brand.dart';
import 'common.dart';

/// قوالب PNG شفافة يصممها فريق الجرافيك (شعار، إطار، عرض حملة...).
/// تنرسم فوق التصميم بكامل المساحة، فالأفضل تكون بنفس نسبة المنشور (مثلاً 1080×1350).
class OverlaysScreen extends StatelessWidget {
  const OverlaysScreen({super.key});

  Future<void> _add(BuildContext context) async {
    // بدون تصغير حتى تبقى الشفافية والدقة الأصلية.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final head = await picked.openRead(0, 4).first;
    final isPng =
        head.length == 4 &&
        head[0] == 0x89 &&
        head[1] == 0x50 &&
        head[2] == 0x4E &&
        head[3] == 0x47;
    if (!isPng) {
      if (context.mounted) {
        toast(context, 'لازم يكون القالب PNG شفاف.');
      }
      return;
    }
    await Store.instance.addOverlay(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final overlays = Store.instance.overlays;
        return Scaffold(
          appBar: AppBar(title: const Text('القوالب')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('رفع قالب PNG'),
          ),
          body: overlays.isEmpty
              ? const EmptyState(
                  icon: Icons.filter_frames_outlined,
                  title: 'ماكو قوالب',
                  body: 'ارفع قوالب PNG شفافة بهوية القسم (إطارات، عروض، حملات). الأفضل بمقاس ١٠٨٠×١٣٥٠ للمنشور أو ١٠٨٠×١٩٢٠ للستوري والفيديو. التطبيق فيه إطار الهوية جاهز.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 4 / 5,
                  ),
                  itemCount: overlays.length,
                  itemBuilder: (_, i) {
                    final path = overlays[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // خلفية مربعات حتى تبين الشفافية.
                          CustomPaint(
                            painter: _Checker(
                              context.brand.line,
                              context.brand.card,
                            ),
                          ),
                          Image.file(
                            errorBuilder: missingPhoto,
                            File(path),
                            fit: BoxFit.contain,
                            cacheWidth: 500,
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: IconButton.filledTonal(
                              tooltip: 'حذف',
                              onPressed: () async {
                                final ok = await confirm(
                                  context,
                                  'حذف القالب؟',
                                  'راح ينحذف من التطبيق فقط.',
                                );
                                if (!ok) return;
                                evictImage(path);
                                await Store.instance.deleteOverlay(path);
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _Checker extends CustomPainter {
  final Color c1, c2;
  const _Checker(this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size size) {
    const s = 12.0;
    final a = Paint()..color = c1;
    final b = Paint()..color = c2;
    for (var y = 0.0; y < size.height; y += s) {
      for (var x = 0.0; x < size.width; x += s) {
        final odd = ((x / s).floor() + (y / s).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), odd ? a : b);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => false;
}
