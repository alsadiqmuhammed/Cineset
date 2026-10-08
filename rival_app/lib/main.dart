import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'brand.dart';
import 'cloud.dart';
import 'lock.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) choose(widget.initial!);
  }

  Future<void> choose(Section s) async {
    setState(() => _opening = true);
    await Store.instance.open(s);
    await Cloud.instance.attach(Store.instance);
    if (!mounted) return;
    setState(() {
      _section = s;
      _opening = false;
    });
  }

  void switchSection() => setState(() => _section = null);

  /// أول مرة: الدخول لحساب العيادة، إلا إذا اختار يشتغل بدون حساب.
  bool get _needsLogin =>
      Cloud.instance.available &&
      !Cloud.instance.signedIn &&
      !Store.instance.cloudSkipped;

  @override
  Widget build(BuildContext context) {
    final s = _section;
    final brand = s == null ? dental : Brand.of(s);
    return MaterialApp(
      title: 'ريڤال',
      debugShowCheckedModeBanner: false,
      theme: brand.theme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: LockGate(
          child: _needsLogin
              ? LoginScreen(onDone: () => setState(() {}))
              : s == null
              ? SectionPicker(onChosen: choose, busy: _opening)
              : HomeShell(key: ValueKey(s)),
        ),
      ),
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
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(onGo: go),
          const PatientsScreen(),
          const ReportsScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: go,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: b.patients,
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'التقارير',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}
