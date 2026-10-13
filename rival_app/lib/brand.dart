import 'package:flutter/material.dart';

/// القسمين: عيادة ريڤال (أسنان) وريڤال بيوتي (تجميل). كل قسم إله هويته وبياناته.
enum Section { dental, beauty }

/// شنو نقطتي المحاذاة: زاويتي الفم للأسنان، والعينين لتجميل الوجه.
enum AlignTarget { mouth, eyes }

const kFontUi = 'Almarai';
const kFontReport = 'Tajawal';
const kFontAccent = 'ArefRuqaa';

/// هوية القسم: الألوان والشعارات والكلمات. مأخوذة من دليلي الهوية.
@immutable
class Brand extends ThemeExtension<Brand> {
  final Section section;
  final String name, latinName, tagline;
  final Color primary, primaryDeep, accent, highlight;
  final Color bg, card, dark, text, muted, line;
  final String logoPrimary, logoReversed, logoHorizontal, symbol;
  final List<String> treatments;
  final bool teethChart;
  final AlignTarget alignTarget;
  final String patient, patients, newPatient;
  final bool feminine;

  /// الوضع الليلي: نفس الهوية بخلفية داكنة.
  final bool isDark;

  const Brand({
    required this.section,
    required this.name,
    required this.latinName,
    required this.tagline,
    required this.primary,
    required this.primaryDeep,
    required this.accent,
    required this.highlight,
    required this.bg,
    required this.card,
    required this.dark,
    required this.text,
    required this.muted,
    required this.line,
    required this.logoPrimary,
    required this.logoReversed,
    required this.logoHorizontal,
    required this.symbol,
    required this.treatments,
    required this.teethChart,
    required this.alignTarget,
    required this.patient,
    required this.patients,
    required this.newPatient,
    required this.feminine,
    this.isDark = false,
  });

  static Brand of(Section s, {bool dark = false}) => s == Section.dental
      ? (dark ? dentalDark : dental)
      : (dark ? beautyDark : beauty);

  /// النسخة الليلية من نفس الهوية.
  Brand get night => Brand.of(section, dark: true);

  /// النسخة الفاتحة (للتصدير والتقارير: دايماً بألوان الهوية الأصلية).
  Brand get day => Brand.of(section);

  // ---------- الزجاج الناعم ----------

  /// لون الظل: مشتق من القسم حتى يبين دافي ومو رمادي.
  Color get shadeDark => isDark
      ? const Color(0xFF000000).withValues(alpha: 0.45)
      : (section == Section.dental
            ? const Color(0xFF8C644F).withValues(alpha: 0.16)
            : const Color(0xFF8C5A5F).withValues(alpha: 0.17));
  Color get shadeLight => isDark
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.08)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.95);

  /// تعبئة البطاقات الزجاجية (شفافة فوق خلفية الصفحة المتدرجة).
  Color get glass => isDark
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.055)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.62);

  /// حافة الزجاج اللامعة.
  Color get glassEdge => isDark
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.09)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.95);

  /// بارز: ظل ناعم ودافي تحت البطاقة.
  List<BoxShadow> raised([double depth = 1]) => [
    BoxShadow(
      color: shadeDark,
      blurRadius: 26 * depth,
      offset: Offset(0, 10 * depth),
    ),
  ];

  /// مجرى غاطس (التبويبات والحقول): زجاج أخف.
  Gradient get pressed => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [
            const Color(0xFF000000).withValues(alpha: 0.28),
            const Color(0xFFFFFFFF).withValues(alpha: 0.03),
          ]
        : [
            Color.alphaBlend(primary.withValues(alpha: 0.05), bg),
            const Color(0xFFFFFFFF).withValues(alpha: 0.45),
          ],
  );

  /// لون حقول الإدخال.
  Color get well => isDark
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.06)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.7);

  /// تدرّج الأزرار والبطاقات الملونة (بلون الهوية الأصلي حتى بالليلي).
  Gradient get action => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: section == Section.dental
        ? const [Color(0xFFE04A28), Color(0xFFA82E12)]
        : const [Color(0xFF8E2D3F), Color(0xFF5A0E1E)],
  );

  /// ظل ملوّن تحت الأزرار المتدرجة.
  List<BoxShadow> get actionShadow => [
    BoxShadow(
      color: day.primaryDeep.withValues(alpha: isDark ? 0.5 : 0.32),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  /// خلفية الصفحات: تدرّج دافي ويا توهج شامبين بالزاوية.
  List<Color> get pageColors => isDark
      ? [
          Color.alphaBlend(primary.withValues(alpha: 0.06), bg),
          bg,
          Color.alphaBlend(const Color(0xFF000000).withValues(alpha: 0.25), bg),
        ]
      : section == Section.dental
      ? const [Color(0xFFFCF7F2), Color(0xFFF7EDE6), Color(0xFFF2E2D6)]
      : const [Color(0xFFFBF6F2), Color(0xFFF6EEE8), Color(0xFFF0DFDA)];

  /// الأزرار والتحية تتبدل حسب القسم (بيوتي بصيغة المؤنث).
  String f(String masc, String fem) => feminine ? fem : masc;

  ThemeData theme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: dark,
          surface: card,
          onSurface: text,
          primaryContainer: primary.withValues(alpha: 0.12),
          onPrimaryContainer: primaryDeep,
          secondaryContainer: accent.withValues(alpha: 0.35),
          onSecondaryContainer: dark,
          outline: line,
          outlineVariant: line,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: kFontUi,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: GlassPageTransitionsBuilder(),
          TargetPlatform.iOS: GlassPageTransitionsBuilder(),
          TargetPlatform.linux: GlassPageTransitionsBuilder(),
          TargetPlatform.macOS: GlassPageTransitionsBuilder(),
          TargetPlatform.windows: GlassPageTransitionsBuilder(),
          TargetPlatform.fuchsia: GlassPageTransitionsBuilder(),
        },
      ),
      colorScheme: scheme,
      // الصفحات شفافة: الخلفية المتدرجة تنرسم ويا انتقال كل صفحة.
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [this],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: kFontUi,
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: well,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      cardColor: card,
      canvasColor: card,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: kFontUi,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDeep,
          side: BorderSide(color: glassEdge),
          backgroundColor: glass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: kFontUi,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glass,
        selectedColor: primary.withValues(alpha: isDark ? 0.3 : 0.14),
        side: BorderSide(color: glassEdge),
        labelStyle: TextStyle(fontFamily: kFontUi, color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.13),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: kFontUi,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? primaryDeep : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: day.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: const TextStyle(
          fontFamily: kFontUi,
          fontWeight: FontWeight.w800,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: line,
      ),
      dividerTheme: DividerThemeData(color: line, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF3A3432) : dark,
        contentTextStyle: const TextStyle(fontFamily: kFontUi),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  /// ظل البطاقات: بارز ناعم.
  List<BoxShadow> get shadow => raised(0.8);

  /// خلفية بطبقات: تدرّج ناعم وإضاءة من الزاوية العليا.
  Gradient get heroGradient => LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color.lerp(primary, Colors.white, 0.08)!, primaryDeep, dark],
    stops: const [0, 0.55, 1],
  );

  @override
  Brand copyWith() => this;

  @override
  Brand lerp(ThemeExtension<Brand>? other, double t) =>
      t < 0.5 ? this : (other as Brand? ?? this);
}

const dental = Brand(
  section: Section.dental,
  name: 'عيادة ريڤال',
  latinName: 'Rival Clinic',
  tagline: 'ابتسامتك مصمّمة بدقة',
  primary: Color(0xFFD33C1A),
  primaryDeep: Color(0xFFA82E12),
  accent: Color(0xFFDBB686),
  highlight: Color(0xFFDBB686),
  bg: Color(0xFFF4F1EC),
  card: Color(0xFFF4F1EC),
  dark: Color(0xFF231F20),
  text: Color(0xFF231F20),
  muted: Color(0xFF6B5F57),
  line: Color(0xFFE6DFD6),
  logoPrimary: 'assets/brand/logo_primary.png',
  logoReversed: 'assets/brand/logo_reversed.png',
  logoHorizontal: 'assets/brand/logo_horizontal.png',
  symbol: 'assets/brand/symbol.png',
  treatments: [
    'ابتسامة هوليوود',
    'فينير',
    'تقويم',
    'تقويم شفاف',
    'تبييض',
    'زراعة',
    'حشوات تجميلية',
    'تنظيف بالبودرة',
    'أسنان الأطفال',
    'علاج عصب',
  ],
  teethChart: true,
  alignTarget: AlignTarget.mouth,
  patient: 'مراجع',
  patients: 'المراجعين',
  newPatient: 'مراجع جديد',
  feminine: false,
);

const beauty = Brand(
  section: Section.beauty,
  name: 'ريڤال بيوتي',
  latinName: 'Rival Beauty',
  tagline: 'جمالچ الطبيعي بلمسة أوضح',
  primary: Color(0xFF5A0E1E),
  primaryDeep: Color(0xFF44050D),
  accent: Color(0xFFDBB686),
  highlight: Color(0xFF9C3D4E),
  bg: Color(0xFFF6EEE8),
  card: Color(0xFFF6EEE8),
  dark: Color(0xFF3A0712),
  text: Color(0xFF3A0712),
  muted: Color(0xFF7A4A55),
  line: Color(0xFFEEDFD8),
  logoPrimary: 'assets/brand/beauty_primary.png',
  logoReversed: 'assets/brand/beauty_reversed.png',
  logoHorizontal: 'assets/brand/beauty_horizontal.png',
  symbol: 'assets/brand/beauty_symbol.png',
  treatments: [
    'فلر',
    'بوتوكس',
    'نضارة البشرة',
    'ميزوثيرابي',
    'تقشير',
    'بلازما',
    'خيوط شد',
    'ليزر',
    'تنظيف بشرة',
  ],
  teethChart: false,
  alignTarget: AlignTarget.eyes,
  patient: 'مراجعة',
  patients: 'المراجعات',
  newPatient: 'مراجعة جديدة',
  feminine: true,
);

/// الوضع الليلي لعيادة ريڤال: نفس الأحمر والبيج على خلفية داكنة دافية.
const dentalDark = Brand(
  section: Section.dental,
  name: 'عيادة ريڤال',
  latinName: 'Rival Clinic',
  tagline: 'ابتسامتك مصمّمة بدقة',
  primary: Color(0xFFE0472A),
  primaryDeep: Color(0xFFFF8E6B),
  accent: Color(0xFFDBB686),
  highlight: Color(0xFFDBB686),
  bg: Color(0xFF1C1918),
  card: Color(0xFF1C1918),
  dark: Color(0xFF0F0D0C),
  text: Color(0xFFF4F1EC),
  muted: Color(0xFFB3A79F),
  line: Color(0xFF35302D),
  logoPrimary: 'assets/brand/logo_primary.png',
  logoReversed: 'assets/brand/logo_reversed.png',
  logoHorizontal: 'assets/brand/logo_horizontal.png',
  symbol: 'assets/brand/symbol.png',
  treatments: [
    'ابتسامة هوليوود',
    'فينير',
    'تقويم',
    'تقويم شفاف',
    'تبييض',
    'زراعة',
    'حشوات تجميلية',
    'تنظيف بالبودرة',
    'أسنان الأطفال',
    'علاج عصب',
  ],
  teethChart: true,
  alignTarget: AlignTarget.mouth,
  patient: 'مراجع',
  patients: 'المراجعين',
  newPatient: 'مراجع جديد',
  feminine: false,
  isDark: true,
);

/// الوضع الليلي لريڤال بيوتي: النبيذي والشامبين على خلفية نبيذية داكنة.
const beautyDark = Brand(
  section: Section.beauty,
  name: 'ريڤال بيوتي',
  latinName: 'Rival Beauty',
  tagline: 'جمالچ الطبيعي بلمسة أوضح',
  primary: Color(0xFF9C3D4E),
  primaryDeep: Color(0xFFEBA9B5),
  accent: Color(0xFFDBB686),
  highlight: Color(0xFFE08A9A),
  bg: Color(0xFF1D1114),
  card: Color(0xFF1D1114),
  dark: Color(0xFF0F080A),
  text: Color(0xFFF6EEE8),
  muted: Color(0xFFC9A5AD),
  line: Color(0xFF3D262C),
  logoPrimary: 'assets/brand/beauty_primary.png',
  logoReversed: 'assets/brand/beauty_reversed.png',
  logoHorizontal: 'assets/brand/beauty_horizontal.png',
  symbol: 'assets/brand/beauty_symbol_reversed.png',
  treatments: [
    'فلر',
    'بوتوكس',
    'نضارة البشرة',
    'ميزوثيرابي',
    'تقشير',
    'بلازما',
    'خيوط شد',
    'ليزر',
    'تنظيف بشرة',
  ],
  teethChart: false,
  alignTarget: AlignTarget.eyes,
  patient: 'مراجعة',
  patients: 'المراجعات',
  newPatient: 'مراجعة جديدة',
  feminine: true,
  isDark: true,
);

extension BrandContext on BuildContext {
  Brand get brand => Theme.of(this).extension<Brand>() ?? dental;
}

/// أرقام عربية بالتصاميم والإحصائيات (أرقام التلفون تبقى مثل ما هي).
String ar(Object n) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().replaceAllMapped(
    RegExp('[0-9]'),
    (m) => d[int.parse(m[0]!)],
  );
}

const arMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

/// الأرقام العربية (٠-٩ و۰-۹) لأرقام إنكليزية.
String latinDigits(String s) => s.replaceAllMapped(
  RegExp('[٠-٩۰-۹]'),
  (m) =>
      '${(m[0]!.codeUnitAt(0) - (m[0]!.codeUnitAt(0) >= 0x6F0 ? 0x6F0 : 0x660))}',
);

/// نص للبحث: بدون تشكيل، والألف والتاء المربوطة والياء بشكل واحد،
/// حتى "اسراء" تلگى "إسراء" و"فاطمه" تلگى "فاطمة".
String searchKey(String s) =>
    latinDigits(s)
        .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(' ', '')
        .toLowerCase();

/// بداية اليوم (بالتوقيت المحلي) حتى نقارن أيام مو ساعات.
int dayOf(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

/// كم يوم تقويمي من [from] لـ[to] (سالب إذا فات).
int daysBetween(int from, int to) =>
    (DateTime.fromMillisecondsSinceEpoch(dayOf(to))
                .difference(DateTime.fromMillisecondsSinceEpoch(dayOf(from)))
                .inHours /
            24)
        .round();

/// التاريخ ويا الساعة إذا محددة: ١٢ تشرين الأول · ٥:٣٠ م
String arDateTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  if (d.hour == 0 && d.minute == 0) return arDate(ms);
  return '${arDate(ms)} · ${arTime(d)}';
}

String arTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${ar(h)}:${ar(m)} ${d.hour < 12 ? 'ص' : 'م'}';
}

/// مبلغ بالدينار: ٢٥٠٬٠٠٠ د.ع
String money(int v) {
  final neg = v < 0;
  final digits = v.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('٬');
    out.write(digits[i]);
  }
  return '${neg ? '-' : ''}${ar(out.toString())} د.ع';
}

/// مبلغ مختصر للأرقام الكبيرة: ٤٫٢ مليون، ٢٥٠ ألف.
String moneyShort(int v) {
  String one(double x) {
    final t = x >= 100 ? x.round().toString() : x.toStringAsFixed(1);
    return ar(t.endsWith('.0') ? t.substring(0, t.length - 2) : t)
        .replaceAll('.', '٫');
  }

  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000) return '$sign${one(a / 1000000)} مليون';
  if (a >= 1000) return '$sign${one(a / 1000)} ألف';
  return '$sign${ar(a)}';
}

/// يقرا رقم مكتوب بأرقام عربية أو إنكليزية، مع فواصل أو بدونها،
/// ويفهم "٢٥٠ ألف" و"١٫٥ مليون".
int? parseAmount(String s) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  final latin = s
      .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${d.indexOf(m[0]!)}')
      .replaceAll('٫', '.');
  final mult = RegExp(r'(مليون|m|M)').hasMatch(latin)
      ? 1000000
      : RegExp(r'(ألف|الف|k|K)').hasMatch(latin)
      ? 1000
      : 1;
  if (mult > 1) {
    final n = RegExp(r'[0-9]+(\.[0-9]+)?')
        .firstMatch(latin.replaceAll(RegExp('[,٬ ]'), ''));
    if (n == null) return null;
    return (double.parse(n[0]!) * mult).round();
  }
  final clean = latin.replaceAll(RegExp(r'[^0-9]'), '');
  return clean.isEmpty ? null : int.tryParse(clean);
}

String arDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${ar(d.day)} ${arMonths[d.month - 1]} ${ar(d.year)}';
}

/// انتقال الصفحات: نفس الحركة الناعمة، وكل صفحة ترسم خلفيتها المتدرجة
/// (الـ Scaffold شفاف حتى تبين البطاقات الزجاجية فوقها).
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  static const _inner = FadeForwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    GlassBackdrop(child: child),
  );
}

/// الخلفية المتدرجة ويا توهجين ناعمين.
class GlassBackdrop extends StatelessWidget {
  final Widget child;
  const GlassBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).extension<Brand>() ?? dental;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: b.pageColors,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1, -1),
            radius: 1.1,
            colors: [
              b.accent.withValues(alpha: b.isDark ? 0.10 : 0.30),
              b.accent.withValues(alpha: 0),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1, 1.05),
              radius: 1.0,
              colors: [
                b.day.primary.withValues(alpha: b.isDark ? 0.12 : 0.10),
                b.day.primary.withValues(alpha: 0),
              ],
            ),
          ),
          child: MediaQuery.sizeOf(context).width > 1320
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: child,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}
