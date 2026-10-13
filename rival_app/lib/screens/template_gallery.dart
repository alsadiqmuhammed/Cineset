import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../design.dart';
import '../render.dart';

/// اسم عائلة القالب (أول جزء من اسمه: «دمج · كريمي · بوست» ← «دمج»).
String templateFamily(DesignTemplate t) {
  final parts = t.label.split(' · ');
  // القوالب الأولى اسمها يبدي بالمقاس («بوست · صورتين»): عائلة «كلاسيك».
  return const {'بوست', 'ستوري', 'مربع'}.contains(parts.first)
      ? 'كلاسيك'
      : parts.first;
}

/// القوالب المفضلة (تنحفظ على الجهاز).
class TemplateFavorites {
  static const _key = 'favorite_templates';
  static final ValueNotifier<Set<String>> ids = ValueNotifier({});
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      ids.value = (p.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      // بدون تخزين: المفضلة تبقى لهاي الجلسة بس.
    }
  }

  static Future<void> toggle(String id) async {
    final next = {...ids.value};
    if (!next.remove(id)) next.add(id);
    ids.value = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, next.toList());
    } catch (_) {}
  }
}

/// معرض القوالب كامل: مجموعات حسب العائلة، فلاتر، ومفضلة.
Future<DesignTemplate?> showTemplateGallery(
  BuildContext context, {
  required List<DesignTemplate> templates,
  DesignTemplate? selected,
}) async {
  await TemplateFavorites.load();
  if (!context.mounted) return null;
  return showModalBottomSheet<DesignTemplate>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _Gallery(templates: templates, selected: selected),
    ),
  );
}

class _Gallery extends StatefulWidget {
  final List<DesignTemplate> templates;
  final DesignTemplate? selected;
  const _Gallery({required this.templates, this.selected});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  PostFormat? _format;
  bool _edgeless = false, _favorites = false, _dark = false;
  int? _photos;

  bool _isDark(DesignTemplate t) =>
      t.id.contains('_dark_') ||
      t.id.contains('_night') ||
      t.id.contains('_wine') ||
      t.id.contains('_noir') ||
      t.id.contains('_ember');

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: TemplateFavorites.ids,
      builder: (context, favs, _) {
        final list = [
          for (final t in widget.templates)
            if ((_format == null || t.format == _format) &&
                (_photos == null || t.photos == _photos) &&
                (!_edgeless || t.edgeless) &&
                (!_favorites || favs.contains(t.id)) &&
                (!_dark || _isDark(t)))
              t,
        ];
        final groups = <String, List<DesignTemplate>>{};
        for (final t in list) {
          groups.putIfAbsent(templateFamily(t), () => []).add(t);
        }
        Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
          child: FilterChip(
            label: Text(label),
            selected: on,
            onSelected: (_) => setState(tap),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Text(
                    'القوالب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: b.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${ar(list.length)} من ${ar(widget.templates.length)}',
                    style: TextStyle(color: b.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                children: [
                  chip('♥ المفضلة', _favorites, () => _favorites = !_favorites),
                  for (final (l, f) in const [
                    ('بوست', PostFormat.portrait),
                    ('ستوري', PostFormat.story),
                    ('مربع', PostFormat.square),
                  ])
                    chip(
                      l,
                      _format == f,
                      () => _format = _format == f ? null : f,
                    ),
                  chip('بدون حواف', _edgeless, () => _edgeless = !_edgeless),
                  chip('غامق', _dark, () => _dark = !_dark),
                  chip(
                    'صورتين',
                    _photos == 2,
                    () => _photos = _photos == 2 ? null : 2,
                  ),
                  chip(
                    'صورة وحدة',
                    _photos == 1,
                    () => _photos = _photos == 1 ? null : 1,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        _favorites
                            ? 'اضغط ♥ على أي قالب حتى ينضاف للمفضلة'
                            : 'ماكو قوالب بهاي الفلاتر',
                        style: TextStyle(color: b.muted),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        for (final e in groups.entries) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                '${e.key}  (${ar(e.value.length)})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: b.text,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.62,
                                  ),
                              itemCount: e.value.length,
                              itemBuilder: (context, i) => _Tile(
                                t: e.value[i],
                                selected: widget.selected?.id == e.value[i].id,
                                favorite: favs.contains(e.value[i].id),
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final DesignTemplate t;
  final bool selected, favorite;
  const _Tile({
    required this.t,
    required this.selected,
    required this.favorite,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final parts = t.label.split(' · ');
    return GestureDetector(
      onTap: () => Navigator.pop(context, t),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: b.line.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? b.primary : b.line,
                  width: selected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(t.asset, fit: BoxFit.contain, cacheWidth: 260),
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: favorite ? 'شيل من المفضلة' : 'أضف للمفضلة',
                      onPressed: () => TemplateFavorites.toggle(t.id),
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: favorite
                            ? const Color(0xFFE5484D)
                            : Colors.white,
                        shadows: const [Shadow(blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            parts.skip(1).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: b.muted),
          ),
        ],
      ),
    );
  }
}
