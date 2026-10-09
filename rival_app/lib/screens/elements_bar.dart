import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../brand.dart';
import '../design.dart';
import '../models.dart';
import '../render.dart';
import '../store.dart';
import 'common.dart';
import 'design_canvas.dart';

/// إضافة وتعديل العناصر فوق التصميم: اسم الطبيب، نص بخطوط العيادة،
/// التوقيع، صورة الطبيب الخاصة، أو أي صورة PNG.
class ElementsBar extends StatelessWidget {
  final DesignController controller;
  final Doctor? doctor;

  /// يضيف اسم الطبيب بمكان ما يركب على شارات قبل/بعد.
  final VoidCallback onAddDoctorName;

  const ElementsBar({
    super.key,
    required this.controller,
    required this.doctor,
    required this.onAddDoctorName,
  });

  Future<void> _addText(BuildContext context) async {
    final text = await editElementText(context, '');
    if (text == null || text.isEmpty) return;
    final b = Store.instance.brand;
    controller.addElement(
      DesignElement.text(
        text,
        font: kFontAccent,
        pillColor: b.dark,
        center: const Offset(0.5, 0.4),
        size: 0.06,
      ),
    );
  }

  Future<String?> _pickPng(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return importPicked(picked);
  }

  Future<void> _addImage(
    BuildContext context,
    ElementRole role, {
    String? path,
  }) async {
    var file = path;
    if (file == null) {
      file = await _pickPng(context);
      if (file == null) return;
      // أول توقيع ينحفظ للطبيب حتى يطلع جاهز بالمرات الجاية وبالتقرير.
      final d = doctor;
      if (role == ElementRole.signature && d != null && d.signature == null) {
        d.signature = file;
        await Store.instance.saveAll();
        if (context.mounted) toast(context, 'انحفظ التوقيع بملف ${d.name}');
      }
    }
    final img = await loadImage(file);
    controller.addElement(
      DesignElement.image(
        img,
        role: role,
        center: role == ElementRole.signature
            ? const Offset(0.78, 0.86)
            : const Offset(0.5, 0.5),
        size: role == ElementRole.signature ? 0.26 : 0.22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final sel = c.selected;
        final d = doctor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (icon, label, onTap) in [
                    (Icons.title, 'نص', () => _addText(context)),
                    if (d != null && c.elementOf(ElementRole.doctor) == null)
                      (Icons.badge_outlined, 'اسم الطبيب', onAddDoctorName),
                    (
                      Icons.draw_outlined,
                      'توقيع',
                      () => _addImage(
                        context,
                        ElementRole.signature,
                        path: d?.signature,
                      ),
                    ),
                    if (d?.stamp != null)
                      (
                        Icons.verified_outlined,
                        'صورة الطبيب',
                        () => _addImage(
                          context,
                          ElementRole.image,
                          path: d!.stamp,
                        ),
                      ),
                    (
                      Icons.add_photo_alternate_outlined,
                      'صورة PNG',
                      () => _addImage(context, ElementRole.image),
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ActionChip(
                        avatar: Icon(icon, size: 18, color: b.primary),
                        label: Text(label),
                        onPressed: onTap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            if (sel != null) ...[
              const SizedBox(height: 6),
              _ElementEditor(controller: c, element: sel),
            ] else if (c.elements.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'اضغط على الاسم أو النص أو التوقيع حتى تحركه أو تعدّله',
                  style: TextStyle(color: b.muted, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ElementEditor extends StatelessWidget {
  final DesignController controller;
  final DesignElement element;
  const _ElementEditor({required this.controller, required this.element});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final e = element;
    final c = controller;
    final colors = [
      Colors.white,
      b.accent,
      b.primary,
      b.dark,
      const Color(0xFF000000),
    ];
    Widget dot(Color col, bool on, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsetsDirectional.only(end: 6),
        decoration: BoxDecoration(
          color: col,
          shape: BoxShape.circle,
          border: Border.all(color: on ? b.primary : b.line, width: on ? 3 : 1),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: b.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: b.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                e.isText ? Icons.title : Icons.image_outlined,
                size: 18,
                color: b.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  e.isText ? e.text : e.role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (e.isText)
                IconButton(
                  tooltip: 'تعديل النص',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final t = await editElementText(context, e.text);
                    if (t != null && t.isNotEmpty) {
                      e.text = t;
                      c.changed();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              IconButton(
                tooltip: 'إرجاعه بدون تدوير',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  e.rotation = 0;
                  c.changed();
                },
                icon: const Icon(Icons.rotate_left, size: 20),
              ),
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                onPressed: () => c.removeElement(e),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
              IconButton(
                tooltip: 'تم',
                visualDensity: VisualDensity.compact,
                onPressed: () => c.select(null),
                icon: const Icon(Icons.check, size: 20),
              ),
            ],
          ),
          if (e.isText) ...[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (font, name) in designFonts)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(name, style: TextStyle(fontFamily: font)),
                        selected: e.font == font,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          e.font = font;
                          c.changed();
                        },
                      ),
                    ),
                  FilterChip(
                    label: const Text('خلفية'),
                    selected: e.pill,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) {
                      e.pill = v;
                      c.changed();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final col in colors)
                    dot(col, e.color == col, () {
                      e.color = col;
                      c.changed();
                    }),
                  if (e.pill) ...[
                    const SizedBox(width: 8),
                    Center(
                      child: Text(
                        'الخلفية:',
                        style: TextStyle(color: b.muted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (final col in colors)
                      dot(col, e.pillColor == col, () {
                        e.pillColor = col;
                        c.changed();
                      }),
                  ],
                ],
              ),
            ),
          ],
          Row(
            children: [
              Icon(Icons.format_size, size: 18, color: b.muted),
              Expanded(
                child: Slider(
                  value: e.isText
                      ? e.size.clamp(0.012, 0.25)
                      : e.size.clamp(0.04, 1.2),
                  min: e.isText ? 0.012 : 0.04,
                  max: e.isText ? 0.25 : 1.2,
                  onChanged: (v) {
                    e.size = v;
                    c.changed();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نافذة كتابة نص العنصر.
Future<String?> editElementText(BuildContext context, String initial) async {
  final ctl = TextEditingController(text: initial);
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('النص'),
      content: TextField(
        controller: ctl,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'مثلاً: ابتسامة هوليود'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
          child: const Text('تم'),
        ),
      ],
    ),
  );
  disposeLater([ctl]);
  return v;
}
