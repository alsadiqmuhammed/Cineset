import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'brand.dart';
import 'elements.dart';
import 'models.dart';
import 'photo_fx.dart';
import 'render.dart';
import 'templates_more.dart';

export 'elements.dart';
export 'photo_fx.dart';

/// قوالب الهوية الجاهزة: صورة PNG شفافة بشبابيك تبين منها الصور.
/// مكان كل شباك مقاس من شفافية القالب نفسه.
class DesignTemplate {
  final String id, label, asset;
  final PostFormat format;
  final List<Rect> slots;

  /// أقنعة الشبابيك (حافة ناعمة، تدرّج، أشكال متداخلة). بدونها الصورة
  /// تنقص على حدود الشباك وفتحة القالب تحدد شكلها.
  final List<SlotMask?>? masks;

  /// مكان شارة قبل/بعد بكل شباك (للشبابيك المتطابقة بقوالب الدمج).
  final List<Alignment>? labelAligns;

  /// لون تحت الصور (يبين من الحواف الناعمة).
  final Color? background;

  /// صورة "بعد" مضببة تملأ الخلفية كلها.
  final bool backdrop;

  /// القالب بيه كلمة قبل/بعد مرسومة، فشارات التطبيق تنطفي تلقائياً.
  final bool bakedLabels;

  /// خط رفيع على حد الدمج (يتحرك ويّا الدمج).
  final Color? seam;

  const DesignTemplate(
    this.id,
    this.label,
    this.asset,
    this.format,
    this.slots, {
    this.masks,
    this.labelAligns,
    this.background,
    this.backdrop = false,
    this.bakedLabels = false,
    this.seam,
  });

  int get photos => slots.length;

  /// بدون حواف: الصورة تذوب بالخلفية أو بالصورة الثانية.
  bool get edgeless => masks?.any((m) => m?.soft ?? false) ?? false;

  /// بيه دمج يتحرك (تدرّج بين الصورتين أو للخلفية).
  bool get blends => masks?.any((m) => m?.fades ?? false) ?? false;

  /// الصورتين بنفس الشباك: الدمج يكدر يغيّر اتجاهه.
  bool get sameFrame => slots.length == 2 && slots[0] == slots[1];
}

const _t = 'assets/templates';

const dentalTemplates = [
  DesignTemplate(
    'dental_post_2',
    'بوست · صورتين',
    '$_t/dental_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(555, 240, 980, 1050), Rect.fromLTRB(100, 240, 525, 1050)],
  ),
  DesignTemplate(
    'dental_post_1',
    'بوست · صورة',
    '$_t/dental_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 240, 970, 1050)],
  ),
  DesignTemplate(
    'dental_story_2',
    'ستوري · صورتين',
    '$_t/dental_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(555, 370, 980, 1420), Rect.fromLTRB(100, 370, 525, 1420)],
  ),
  DesignTemplate(
    'dental_story_1',
    'ستوري · صورة',
    '$_t/dental_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 370, 970, 1420)],
  ),
  DesignTemplate(
    'dental_soft_post_2',
    'ناعم · بوست · صورتين',
    '$_t/dental_soft_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 280, 980, 1050), Rect.fromLTRB(100, 280, 520, 1050)],
  ),
  DesignTemplate(
    'dental_soft_post_1',
    'ناعم · بوست · صورة',
    '$_t/dental_soft_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 280, 950, 1050)],
  ),
  DesignTemplate(
    'dental_soft_story_2',
    'ناعم · ستوري · صورتين',
    '$_t/dental_soft_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'dental_soft_story_1',
    'ناعم · ستوري · صورة',
    '$_t/dental_soft_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'dental_red_post_2',
    'أحمر · بوست · صورتين',
    '$_t/dental_red_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 280, 980, 1050), Rect.fromLTRB(100, 280, 520, 1050)],
  ),
  DesignTemplate(
    'dental_red_post_1',
    'أحمر · بوست · صورة',
    '$_t/dental_red_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 280, 950, 1050)],
  ),
  DesignTemplate(
    'dental_red_story_2',
    'أحمر · ستوري · صورتين',
    '$_t/dental_red_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'dental_red_story_1',
    'أحمر · ستوري · صورة',
    '$_t/dental_red_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'dental_night_post_2',
    'ليلي ذهبي · بوست · صورتين',
    '$_t/dental_night_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 280, 980, 1050), Rect.fromLTRB(100, 280, 520, 1050)],
  ),
  DesignTemplate(
    'dental_night_post_1',
    'ليلي ذهبي · بوست · صورة',
    '$_t/dental_night_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 280, 950, 1050)],
  ),
  DesignTemplate(
    'dental_night_story_2',
    'ليلي ذهبي · ستوري · صورتين',
    '$_t/dental_night_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'dental_night_story_1',
    'ليلي ذهبي · ستوري · صورة',
    '$_t/dental_night_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'dental_marble_post_2',
    'رخام أبيض · بوست · صورتين',
    '$_t/dental_marble_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 270, 970, 659), Rect.fromLTRB(110, 687, 970, 1075)],
  ),
  DesignTemplate(
    'dental_marble_post_1',
    'رخام أبيض · بوست · صورة',
    '$_t/dental_marble_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 270, 970, 1075)],
  ),
  DesignTemplate(
    'dental_marble_story_2',
    'رخام أبيض · ستوري · صورتين',
    '$_t/dental_marble_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 380, 970, 912), Rect.fromLTRB(110, 948, 970, 1480)],
  ),
  DesignTemplate(
    'dental_marble_story_1',
    'رخام أبيض · ستوري · صورة',
    '$_t/dental_marble_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 380, 970, 1480)],
  ),
  DesignTemplate(
    'dental_ember_post_2',
    'جمري · بوست · صورتين',
    '$_t/dental_ember_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 290, 980, 1050), Rect.fromLTRB(100, 290, 520, 1050)],
  ),
  DesignTemplate(
    'dental_ember_post_1',
    'جمري · بوست · صورة',
    '$_t/dental_ember_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 290, 950, 1050)],
  ),
  DesignTemplate(
    'dental_ember_story_2',
    'جمري · ستوري · صورتين',
    '$_t/dental_ember_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'dental_ember_story_1',
    'جمري · ستوري · صورة',
    '$_t/dental_ember_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'dental_editorial_post_2',
    'مجلة · بوست · صورتين',
    '$_t/dental_editorial_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 270, 970, 659), Rect.fromLTRB(110, 687, 970, 1075)],
  ),
  DesignTemplate(
    'dental_editorial_post_1',
    'مجلة · بوست · صورة',
    '$_t/dental_editorial_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 270, 970, 1075)],
  ),
  DesignTemplate(
    'dental_editorial_story_2',
    'مجلة · ستوري · صورتين',
    '$_t/dental_editorial_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 380, 970, 912), Rect.fromLTRB(110, 948, 970, 1480)],
  ),
  DesignTemplate(
    'dental_editorial_story_1',
    'مجلة · ستوري · صورة',
    '$_t/dental_editorial_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 380, 970, 1480)],
  ),
  DesignTemplate(
    'dental_glass_post_2',
    'زجاجي · بوست · صورتين',
    '$_t/dental_glass_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 290, 980, 1050), Rect.fromLTRB(100, 290, 520, 1050)],
  ),
  DesignTemplate(
    'dental_glass_post_1',
    'زجاجي · بوست · صورة',
    '$_t/dental_glass_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 290, 950, 1050)],
  ),
  DesignTemplate(
    'dental_glass_story_2',
    'زجاجي · ستوري · صورتين',
    '$_t/dental_glass_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'dental_glass_story_1',
    'زجاجي · ستوري · صورة',
    '$_t/dental_glass_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
];

const beautyTemplates = [
  DesignTemplate(
    'beauty_post_2',
    'بوست · صورتين',
    '$_t/beauty_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(558, 320, 970, 1050), Rect.fromLTRB(110, 250, 522, 980)],
  ),
  DesignTemplate(
    'beauty_post_1',
    'بوست · صورة',
    '$_t/beauty_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(160, 250, 920, 1050)],
  ),
  DesignTemplate(
    'beauty_story_2',
    'ستوري · صورتين',
    '$_t/beauty_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(558, 450, 970, 1420), Rect.fromLTRB(110, 380, 522, 1350)],
  ),
  DesignTemplate(
    'beauty_story_1',
    'ستوري · صورة',
    '$_t/beauty_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(140, 380, 940, 1420)],
  ),
  DesignTemplate(
    'beauty_blush_post_2',
    'أقواس وردية · بوست · صورتين',
    '$_t/beauty_blush_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 350, 980, 1050), Rect.fromLTRB(100, 280, 520, 980)],
  ),
  DesignTemplate(
    'beauty_blush_post_1',
    'أقواس وردية · بوست · صورة',
    '$_t/beauty_blush_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 280, 950, 1050)],
  ),
  DesignTemplate(
    'beauty_blush_story_2',
    'أقواس وردية · ستوري · صورتين',
    '$_t/beauty_blush_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 470, 980, 1420), Rect.fromLTRB(100, 400, 520, 1350)],
  ),
  DesignTemplate(
    'beauty_blush_story_1',
    'أقواس وردية · ستوري · صورة',
    '$_t/beauty_blush_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'beauty_wine_post_2',
    'نبيذي فاخر · بوست · صورتين',
    '$_t/beauty_wine_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 280, 980, 1050), Rect.fromLTRB(100, 280, 520, 1050)],
  ),
  DesignTemplate(
    'beauty_wine_post_1',
    'نبيذي فاخر · بوست · صورة',
    '$_t/beauty_wine_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 280, 950, 1050)],
  ),
  DesignTemplate(
    'beauty_wine_story_2',
    'نبيذي فاخر · ستوري · صورتين',
    '$_t/beauty_wine_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'beauty_wine_story_1',
    'نبيذي فاخر · ستوري · صورة',
    '$_t/beauty_wine_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'beauty_champagne_post_2',
    'شامبين · بوست · صورتين',
    '$_t/beauty_champagne_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 280, 980, 1050), Rect.fromLTRB(100, 280, 520, 1050)],
  ),
  DesignTemplate(
    'beauty_champagne_post_1',
    'شامبين · بوست · صورة',
    '$_t/beauty_champagne_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 280, 950, 1050)],
  ),
  DesignTemplate(
    'beauty_champagne_story_2',
    'شامبين · ستوري · صورتين',
    '$_t/beauty_champagne_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'beauty_champagne_story_1',
    'شامبين · ستوري · صورة',
    '$_t/beauty_champagne_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'beauty_rosegold_post_2',
    'روز جولد · بوست · صورتين',
    '$_t/beauty_rosegold_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 290, 980, 1050), Rect.fromLTRB(100, 290, 520, 1050)],
  ),
  DesignTemplate(
    'beauty_rosegold_post_1',
    'روز جولد · بوست · صورة',
    '$_t/beauty_rosegold_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(170, 290, 910, 1050)],
  ),
  DesignTemplate(
    'beauty_rosegold_story_2',
    'روز جولد · ستوري · صورتين',
    '$_t/beauty_rosegold_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'beauty_rosegold_story_1',
    'روز جولد · ستوري · صورة',
    '$_t/beauty_rosegold_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(170, 400, 910, 1420)],
  ),
  DesignTemplate(
    'beauty_noir_post_2',
    'أسود ملكي · بوست · صورتين',
    '$_t/beauty_noir_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 360, 980, 1050), Rect.fromLTRB(100, 290, 520, 980)],
  ),
  DesignTemplate(
    'beauty_noir_post_1',
    'أسود ملكي · بوست · صورة',
    '$_t/beauty_noir_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 290, 950, 1050)],
  ),
  DesignTemplate(
    'beauty_noir_story_2',
    'أسود ملكي · ستوري · صورتين',
    '$_t/beauty_noir_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 470, 980, 1420), Rect.fromLTRB(100, 400, 520, 1350)],
  ),
  DesignTemplate(
    'beauty_noir_story_1',
    'أسود ملكي · ستوري · صورة',
    '$_t/beauty_noir_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
  DesignTemplate(
    'beauty_petal_post_2',
    'بتلات · بوست · صورتين',
    '$_t/beauty_petal_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 270, 970, 659), Rect.fromLTRB(110, 687, 970, 1075)],
  ),
  DesignTemplate(
    'beauty_petal_post_1',
    'بتلات · بوست · صورة',
    '$_t/beauty_petal_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(110, 270, 970, 1075)],
  ),
  DesignTemplate(
    'beauty_petal_story_2',
    'بتلات · ستوري · صورتين',
    '$_t/beauty_petal_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 380, 970, 912), Rect.fromLTRB(110, 948, 970, 1480)],
  ),
  DesignTemplate(
    'beauty_petal_story_1',
    'بتلات · ستوري · صورة',
    '$_t/beauty_petal_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(110, 380, 970, 1480)],
  ),
  DesignTemplate(
    'beauty_pearl_post_2',
    'لؤلؤي · بوست · صورتين',
    '$_t/beauty_pearl_post_2.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(560, 290, 980, 1050), Rect.fromLTRB(100, 290, 520, 1050)],
  ),
  DesignTemplate(
    'beauty_pearl_post_1',
    'لؤلؤي · بوست · صورة',
    '$_t/beauty_pearl_post_1.webp',
    PostFormat.portrait,
    [Rect.fromLTRB(130, 290, 950, 1050)],
  ),
  DesignTemplate(
    'beauty_pearl_story_2',
    'لؤلؤي · ستوري · صورتين',
    '$_t/beauty_pearl_story_2.webp',
    PostFormat.story,
    [Rect.fromLTRB(560, 400, 980, 1420), Rect.fromLTRB(100, 400, 520, 1420)],
  ),
  DesignTemplate(
    'beauty_pearl_story_1',
    'لؤلؤي · ستوري · صورة',
    '$_t/beauty_pearl_story_1.webp',
    PostFormat.story,
    [Rect.fromLTRB(130, 400, 950, 1420)],
  ),
];

/// كل قوالب القسم: الكلاسيكي الأول (الافتراضي)، بعده العائلات الجديدة،
/// وبعدها باقي القوالب الأولى.
List<DesignTemplate> templatesFor(Section s) {
  final (base, more) = s == Section.dental
      ? (dentalTemplates, dentalMore)
      : (beautyTemplates, beautyMore);
  return [base.first, ...more, ...base.skip(1)];
}

/// أي صورة بالشباك.
enum Which {
  before('قبل'),
  after('بعد');

  final String label;
  const Which(this.label);
}

class SlotFill {
  Which which;
  Framing framing;
  SlotFill(this.which, [this.framing = const Framing()]);

  SlotFill copy() => SlotFill(which, framing);
}

/// أدوات التعديل. كلها تنرسم بطبقة وحدة فوق الصور وتحت القالب،
/// فالممحاة تمسح أي إضافة بس ما تمس الصور ولا القالب.
enum MarkKind {
  pen('رسم', 'draw'),
  arrow('سهم', 'arrow'),
  circle('دائرة', 'circle'),
  rect('مربع', 'rect'),
  blurRect('تضبيب', 'blur'),
  blurBrush('تضبيب حر', 'blurBrush'),
  eraser('ممحاة', 'eraser');

  final String label, key;
  const MarkKind(this.label, this.key);

  bool get freehand =>
      this == MarkKind.pen ||
      this == MarkKind.eraser ||
      this == MarkKind.blurBrush;
}

class Mark {
  final MarkKind kind;
  final List<Offset> points;
  final Color color;

  /// عرض الخط (أو فرشاة التضبيب) بنسبة من عرض التصميم.
  final double width;
  Mark(this.kind, this.points, this.color, this.width);
}

class DesignSpec {
  final Brand brand;
  final Size size;
  final List<Rect> slots;
  final List<SlotFill> fills;
  final Map<Which, (ui.Image, Photo)> photos;
  final ui.Image? template;
  final ui.Image? overlay;
  final BrandFrame? frame;
  final bool labels;

  /// شارات قبل/بعد جوّه الشباك (مع القوالب والإطار) أو فوق.
  final bool labelsAtBottom;
  final List<Mark> marks;

  /// نصوص وصور تتحرك فوق كل شي (اسم الطبيب، توقيع...).
  final List<DesignElement> elements;

  final List<SlotMask?>? masks;
  final List<Alignment>? labelAligns;
  final Color? background;
  final bool backdrop;
  final Color? seam;

  /// تعديل الإضاءة والألوان لكل صورة.
  final Map<Which, PhotoAdjust> adjust;

  const DesignSpec({
    required this.brand,
    required this.size,
    required this.slots,
    required this.fills,
    required this.photos,
    this.template,
    this.overlay,
    this.frame,
    this.labels = true,
    this.labelsAtBottom = false,
    this.marks = const [],
    this.elements = const [],
    this.masks,
    this.labelAligns,
    this.background,
    this.backdrop = false,
    this.adjust = const {},
    this.seam,
  });

  /// القالب يجيب الأقنعة والخلفية ويّاه.
  DesignSpec.templated({
    required this.brand,
    required DesignTemplate t,
    required this.fills,
    required this.photos,
    required ui.Image this.template,
    this.labels = true,
    this.marks = const [],
    this.elements = const [],
    this.adjust = const {},
  }) : size = t.format.size,
       slots = t.slots,
       overlay = null,
       frame = null,
       labelsAtBottom = true,
       masks = t.masks,
       labelAligns = t.labelAligns,
       background = t.background,
       backdrop = t.backdrop,
       seam = t.seam;

  Alignment labelAlign(int i) => labelAligns != null && i < labelAligns!.length
      ? labelAligns![i]
      : labelsAtBottom
      ? Alignment.bottomCenter
      : Alignment.topCenter;

  DesignSpec copyWith({
    List<SlotFill>? fills,
    bool clearTemplate = false,
    bool clearOverlay = false,
    bool clearFrame = false,
    bool? labels,
    List<Mark>? marks,
    List<DesignElement>? elements,
    Map<Which, PhotoAdjust>? adjust,
  }) => DesignSpec(
    brand: brand,
    size: size,
    slots: slots,
    fills: fills ?? this.fills,
    photos: photos,
    template: clearTemplate ? null : template,
    overlay: clearOverlay ? null : overlay,
    frame: clearFrame ? null : frame,
    labels: labels ?? this.labels,
    labelsAtBottom: labelsAtBottom,
    marks: marks ?? this.marks,
    elements: elements ?? this.elements,
    masks: masks,
    labelAligns: labelAligns,
    background: background,
    backdrop: backdrop,
    adjust: adjust ?? this.adjust,
    seam: seam,
  );

  /// أماكن شارات قبل/بعد (حتى اسم الطبيب ما يركب عليها).
  List<Rect> get labelRects => [
    if (labels)
      for (var i = 0; i < slots.length && i < fills.length; i++)
        labelRect(
          labelsAtBottom ? slots[i].deflate(size.width * 0.01) : slots[i],
          fills[i].which.label,
          size.width,
          align: labelAlign(i),
        ),
  ];
}

/// أماكن مقترحة لاسم الطبيب (بالترتيب): تحت الشعار بالإطار، وبأعلى الصور
/// بالقوالب، وإلا تحت أو فوق التصميم.
List<Offset> nameSpots(
  Size s,
  List<Rect> slots, {
  required bool templated,
  required bool framed,
}) {
  double y(double px) => px / s.height;
  final unit = math.min(s.width, s.height);
  final all = slots.reduce((a, b) => a.expandToInclude(b));
  final gap = s.width * 0.045;
  return [
    if (!templated && framed) Offset(0.5, y(unit * 0.23)),
    // القوالب بيها كتابة تحت الشبابيك وفوقها، فالاسم بأعلى الصورة
    // (شارات قبل/بعد تكون بأسفلها).
    if (templated) Offset(0.5, y(all.top + gap * 1.3)),
    Offset(0.5, 1 - y(gap * 1.4)),
    Offset(0.5, y(gap * 1.4)),
    Offset(0.5, y(all.center.dy)),
  ];
}

/// عنصر اسم الطبيب بألوان الهوية، بمكان ما يركب على شارات قبل/بعد.
DesignElement doctorNameElement(String name, Brand b) => DesignElement.text(
  name,
  role: ElementRole.doctor,
  color: b.dark,
  pill: true,
  pillColor: b.accent,
  size: 0.034,
);

/// يرسم التصميم كامل. نفس الدالة للمعاينة الحيّة وللتصدير.
/// الترتيب: الخلفية ← الصور ← طبقة الإضافات (تضبيب، أشكال، رسم، ممحاة)
/// ← القالب/الإطار ← شارات قبل وبعد.
void paintDesign(Canvas canvas, DesignSpec s) {
  final full = Offset.zero & s.size;
  canvas.drawRect(
    full,
    Paint()
      ..color =
          s.background ?? (s.template == null ? s.brand.accent : s.brand.bg),
  );

  void photos(Canvas c) {
    for (var i = 0; i < s.slots.length && i < s.fills.length; i++) {
      final fill = s.fills[i];
      final p = s.photos[fill.which];
      if (p == null) continue;
      final m = s.masks != null && i < s.masks!.length ? s.masks![i] : null;
      final adj = s.adjust[fill.which] ?? PhotoAdjust.none;
      final filter = (m?.mono ?? false)
          ? adj.copyWith(saturation: -1).filter
          : adj.filter;
      void draw(Canvas c) => paintPhoto(
        c,
        s.slots[i],
        p.$1,
        p.$2,
        fill.framing,
        filter: filter,
        backing: s.masks == null,
      );
      if (m == null) {
        draw(c);
      } else {
        paintMasked(c, s.slots[i], m, draw);
      }
    }
  }

  if (s.backdrop) _paintBackdrop(canvas, s);
  photos(canvas);
  if (s.seam != null) _paintSeam(canvas, s);

  if (s.marks.isNotEmpty) {
    canvas.saveLayer(full, Paint());
    for (final m in s.marks) {
      _paintMark(canvas, m, s, photos);
    }
    canvas.restore();
  }

  if (s.template != null) {
    canvas.drawImageRect(
      s.template!,
      Rect.fromLTWH(
        0,
        0,
        s.template!.width.toDouble(),
        s.template!.height.toDouble(),
      ),
      full,
      Paint()..filterQuality = FilterQuality.high,
    );
  }
  paintOverlay(canvas, s.size, s.overlay);
  if (s.frame != null) paintBrandFrame(canvas, s.size, s.frame!);

  if (s.labels) {
    for (var i = 0; i < s.slots.length && i < s.fills.length; i++) {
      final which = s.fills[i].which;
      final cell = s.slots[i];
      final templated = s.labelsAtBottom;
      paintLabel(
        canvas,
        templated ? cell.deflate(s.size.width * 0.01) : cell,
        which.label,
        s.size.width,
        bg: which == Which.after ? s.brand.primary : s.brand.dark,
        fg: const Color(0xFFFFFFFF),
        align: s.labelAlign(i),
      );
    }
  }
  paintElements(canvas, s.size, s.elements);
}

/// خط رفيع على حد الدمج، مقصوص على الشباك.
void _paintSeam(Canvas canvas, DesignSpec s) {
  final masks = s.masks;
  if (masks == null) return;
  for (var i = 0; i < masks.length && i < s.slots.length; i++) {
    final cell = s.slots[i];
    final line = masks[i]?.seamIn(cell);
    if (line == null) continue;
    final (p, d) = line;
    final n = d / d.distance * (cell.longestSide * 1.5);
    final a = p - n, b = p + n;
    final inner = cell.deflate((masks[i]!.feather * 2.5).clamp(0, 400));
    canvas.save();
    canvas.clipRect(inner);
    final w = s.size.width * 0.003;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = s.seam!.withValues(alpha: 0.35)
        ..strokeWidth = w * 5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 3),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = s.seam!
        ..strokeWidth = w,
    );
    canvas.restore();
    return;
  }
}

/// صورة "بعد" مضببة ومعتّمة شوية تملأ التصميم (خلفية القوالب الفخمة).
void _paintBackdrop(Canvas canvas, DesignSpec s) {
  final p = s.photos[Which.after] ?? s.photos[Which.before];
  if (p == null) return;
  final full = Offset.zero & s.size;
  final sigma = s.size.width * 0.03;
  canvas.save();
  canvas.clipRect(full);
  canvas.saveLayer(
    full,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.clamp,
      ),
  );
  final img = p.$1;
  final src = Size(img.width.toDouble(), img.height.toDouble());
  final fit = applyBoxFit(BoxFit.cover, src, s.size);
  canvas.drawImageRect(
    img,
    Alignment.center.inscribe(fit.source, Offset.zero & src),
    full,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = s.adjust[Which.after]?.filter,
  );
  canvas.restore();
  canvas.drawRect(full, Paint()..color = const Color(0x33000000));
  canvas.restore();
}

void _paintMark(
  Canvas canvas,
  Mark m,
  DesignSpec s,
  void Function(Canvas) photos,
) {
  final w = m.width * s.size.width;
  final stroke = Paint()
    ..color = m.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  switch (m.kind) {
    case MarkKind.pen:
      canvas.drawPath(_smooth(m.points), stroke);
    case MarkKind.eraser:
      canvas.drawPath(
        _smooth(m.points),
        stroke
          ..blendMode = BlendMode.clear
          ..strokeWidth = w * 2.5,
      );
    case MarkKind.arrow:
      if (m.points.length < 2) return;
      final a = m.points.first, b = m.points.last;
      final d = b - a;
      if (d.distance < 1) return;
      final head = math.min(d.distance * 0.45, w * 5);
      final dir = d / d.distance;
      final base = b - dir * head * 0.8;
      canvas.drawLine(a, base, stroke);
      final n = Offset(-dir.dy, dir.dx);
      canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(
            (b - dir * head + n * head * 0.55).dx,
            (b - dir * head + n * head * 0.55).dy,
          )
          ..lineTo(
            (b - dir * head - n * head * 0.55).dx,
            (b - dir * head - n * head * 0.55).dy,
          )
          ..close(),
        Paint()
          ..color = m.color
          ..isAntiAlias = true,
      );
    case MarkKind.circle:
      if (m.points.length < 2) return;
      canvas.drawOval(Rect.fromPoints(m.points.first, m.points.last), stroke);
    case MarkKind.rect:
      if (m.points.length < 2) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(m.points.first, m.points.last),
          Radius.circular(w * 1.5),
        ),
        stroke,
      );
    case MarkKind.blurRect:
    case MarkKind.blurBrush:
      final Path area;
      if (m.kind == MarkKind.blurRect) {
        if (m.points.length < 2) return;
        area = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromPoints(m.points.first, m.points.last),
              Radius.circular(s.size.width * 0.012),
            ),
          );
      } else {
        area = _brushArea(m.points, w * 2.5);
      }
      final sigma = s.size.width * 0.018;
      final bounds = area.getBounds().inflate(sigma * 3);
      canvas.save();
      canvas.clipPath(area);
      canvas.saveLayer(
        bounds,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
      );
      photos(canvas);
      canvas.restore();
      canvas.restore();
  }
}

/// خط ناعم بين النقاط (منتصفات بمنحنيات).
Path _smooth(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) {
    path.lineTo(pts.first.dx + 0.1, pts.first.dy);
    return path;
  }
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = (pts[i] + pts[i + 1]) / 2;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// منطقة فرشاة التضبيب: دوائر على طول المسار.
Path _brushArea(List<Offset> pts, double r) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    path.addOval(Rect.fromCircle(center: pts[i], radius: r));
    if (i == 0) continue;
    final a = pts[i - 1], b = pts[i];
    final steps = ((b - a).distance / (r * 0.5)).ceil();
    for (var k = 1; k < steps; k++) {
      path.addOval(
        Rect.fromCircle(center: Offset.lerp(a, b, k / steps)!, radius: r),
      );
    }
  }
  return path;
}

Future<ui.Image> renderDesign(DesignSpec s, {double scale = 1}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  paintDesign(canvas, s);
  return recorder.endRecording().toImage(
    (s.size.width * scale).round(),
    (s.size.height * scale).round(),
  );
}

/// أقل تقريب يخلّي الصورة تملأ شباكها.
Framing fitFraming(Rect cell, ui.Image img, Photo p, Framing f) {
  final z = coverZoom(
    cell,
    Size(img.width.toDouble(), img.height.toDouble()),
    p,
    f,
  );
  return f.copyWith(zoom: math.max(1.0, z).clamp(0.3, 6.0));
}
