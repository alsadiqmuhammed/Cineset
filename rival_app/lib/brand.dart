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
  });

  static Brand of(Section s) => s == Section.dental ? dental : beauty;

  /// الأزرار والتحية تتبدل حسب القسم (بيوتي بصيغة المؤنث).
  String f(String masc, String fem) => feminine ? fem : masc;

  ThemeData theme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
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
      fontFamily: kFontUi,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      extensions: [this],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
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
        fillColor: card,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: kFontUi,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDeep,
          side: BorderSide(color: line),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: kFontUi,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primary.withValues(alpha: 0.14),
        side: BorderSide(color: line),
        labelStyle: TextStyle(fontFamily: kFontUi, color: text),
        shape: const StadiumBorder(),
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
        backgroundColor: primary,
        foregroundColor: Colors.white,
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
        backgroundColor: dark,
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

  /// ظل دافي بثلاث طبقات (ملامس، متوسط، ناعم بعيد) بلون القسم مو أسود.
  List<BoxShadow> get shadow => [
    BoxShadow(
      color: primaryDeep.withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: primaryDeep.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: primaryDeep.withValues(alpha: 0.07),
      blurRadius: 30,
      offset: const Offset(0, 14),
    ),
  ];

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
  card: Color(0xFFFFFFFF),
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
  card: Color(0xFFFFFFFF),
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
