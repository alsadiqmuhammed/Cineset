import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'brand.dart';
import 'cloud.dart';
import 'lock.dart';
import 'screens/appointments_screen.dart';
import 'screens/common.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/more_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/section_picker.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.init();
  await Cloud.instance.init();
  Net.instance.start();
  runApp(const RivalApp());
}

/// يبدأ باختيار القسم (أسنان أو تجميل)، وبعدها يفتح القسم بهويته وبياناته.
class RivalApp extends StatefulWidget {
  /// للاختبارات: يفتح القسم مباشرة بدون شاشة الاختيار.
  final Section? initial;
  const RivalApp({super.key, this.initial});

  static RivalAppState of(BuildContext context) =>
      context.findAncestorStateOfType<RivalAppState>()!;

  @override
  State<RivalApp> createState() => RivalAppState();
}

class RivalAppState extends State<RivalApp> {
  Section? _section;
  bool _opening = false;

  String? _account = Store.instance.account;

  @override
  void initState() {
    super.initState();
    Cloud.instance.addListener(_accountChanged);
    if (widget.initial != null) {
      choose(widget.initial!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpen());
    }
  }

  @override
  void dispose() {
    Cloud.instance.removeListener(_accountChanged);
    super.dispose();
  }

  /// دخول أو خروج: نرجع لاختيار القسم ببيانات الحساب الجديد.
  void _accountChanged() {
    if (Store.instance.account == _account) return;
    _account = Store.instance.account;
    if (!mounted) return;
    setState(() => _section = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpen());
  }

  /// الطبيب اللي إله قسم واحد يدخل عليه مباشرة.
  void _autoOpen() {
    if (_section != null || _opening || _needsLogin) return;
    final allowed = allowedSections;
    if (allowed.length == 1) choose(allowed.first);
  }

  List<Section> get allowedSections {
    final m = Cloud.instance.member;
    if (m == null || m.isAdmin) return Section.values;
    return [
      for (final s in Section.values)
        if (m.canOpen(s.name)) s,
    ];
  }

  Future<void> choose(Section s) async {
    // ضغطتين سريعة على مبدّل القسم ما تفتح مرتين.
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Store.instance.open(s);
      await Cloud.instance.attach(Store.instance);
      if (!mounted) return;
      setState(() => _section = s);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void switchSection() => setState(() => _section = null);

  /// أول مرة: الدخول لحساب العيادة، إلا إذا اختار يشتغل بدون حساب.
  bool get _needsLogin =>
      Cloud.instance.available &&
      !Cloud.instance.signedIn &&
      // نسخة الويب دايماً بحساب العيادة (ماكو تخزين بالمتصفح).
      (kIsWeb || !Store.instance.cloudSkipped);

  @override
  Widget build(BuildContext context) {
    final s = _section;
    final brand = s == null ? dental : Brand.of(s);
    return ValueListenableBuilder<String>(
      valueListenable: Store.instance.look,
      builder: (context, look, _) => _app(brand, look),
    );
  }

  Widget _app(Brand brand, String look) {
    final s = _section;
    final mode = switch (look) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'ريڤال',
      debugShowCheckedModeBanner: false,
      theme: brand.theme(),
      darkTheme: brand.night.theme(),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              (context.brand.isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(statusBarColor: Colors.transparent),
          child: _needsLogin
              ? LoginScreen(
                  onDone: () {
                    _account = Store.instance.account;
                    setState(() {});
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _autoOpen(),
                    );
                  },
                )
              : s == null
              ? SectionPicker(
                  onChosen: choose,
                  busy: _opening,
                  allowed: allowedSections,
                )
              : HomeShell(key: ValueKey(s)),
        ),
      ),
      builder: (context, child) => LockGate(child: child!),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
      (Icons.people_outline, Icons.people_rounded, b.patients),
      (Icons.event_note_outlined, Icons.event_note_rounded, 'المواعيد'),
      (Icons.insights_outlined, Icons.insights_rounded, 'التقارير'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'المزيد'),
    ];
    final pages = IndexedStack(
      index: _tab,
      children: [
        DashboardScreen(onGo: go),
        const PatientsScreen(),
        const AppointmentsScreen(),
        const ReportsScreen(),
        const MoreScreen(),
      ],
    );
    // شاشة عريضة (كمبيوتر أو آيباد): قائمة جانبية والمحتوى بعرض مريح.
    if (MediaQuery.sizeOf(context).width >= 900) {
      return Scaffold(
        body: Row(
          children: [
            _SideBar(index: _tab, onTap: go, items: items),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: pages,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: _NeuNavBar(index: _tab, onTap: go, items: items),
    );
  }
}

/// القائمة الجانبية الزجاجية للشاشات العريضة.
class _SideBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  const _SideBar({
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      width: 248,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      decoration: BoxDecoration(
        color: b.glass,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: b.glassEdge),
        boxShadow: b.raised(0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            b.isDark ? b.logoReversed : b.logoPrimary,
            height: 86,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: i == index
                    ? b.primary.withValues(alpha: b.isDark ? 0.22 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          i == index ? items[i].$2 : items[i].$1,
                          color: i == index ? b.primaryDeep : b.muted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: i == index
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: i == index ? b.primaryDeep : b.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          const SectionSwitch(),
          const SizedBox(height: 10),
          Text(
            Cloud.instance.user?.email ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: b.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// شريط سفلي عائم بارز، والتبويب المختار غاطس لجوه بنعومة.
class _NeuNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  const _NeuNavBar({
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: b.isDark
                ? Color.alphaBlend(const Color(0x14FFFFFF), b.card)
                : const Color(0xD9FFFFFF),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: b.glassEdge),
            boxShadow: b.raised(0.9),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: _NavItem(
                        on: i == index,
                        icon: i == index ? items[i].$2 : items[i].$1,
                        label: items[i].$3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool on;
  final IconData icon;
  final String label;
  const _NavItem({required this.on, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: on ? 52 : 40,
          height: 34,
          decoration: BoxDecoration(
            color: on
                ? b.primary.withValues(alpha: b.isDark ? 0.22 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            scale: on ? 1.08 : 1,
            child: Icon(icon, size: 22, color: on ? b.primaryDeep : b.muted),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontFamily: kFontUi,
            fontSize: 10.5,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
            color: on ? b.primaryDeep : b.muted,
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.fade),
        ),
      ],
    );
  }
}
