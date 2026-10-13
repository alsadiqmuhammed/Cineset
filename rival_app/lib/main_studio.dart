import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'brand.dart';
import 'screens/studio_home.dart';
import 'store.dart';

/// ريڤال ستوديو: تطبيق منفصل بس لتصميم حالات قبل وبعد بقوالب الهوية.
/// ما بيه حساب ولا مراجعين؛ تختار صورتين وتصمم وتنشر.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.init();
  await Store.instance.open(Section.dental);
  runApp(const StudioApp());
}

class StudioApp extends StatefulWidget {
  const StudioApp({super.key});

  static StudioAppState of(BuildContext context) =>
      context.findAncestorStateOfType<StudioAppState>()!;

  @override
  State<StudioApp> createState() => StudioAppState();
}

class StudioAppState extends State<StudioApp> {
  Section get section => Store.instance.section;

  Future<void> choose(Section s) async {
    if (s == section) return;
    await Store.instance.open(s);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brand = Brand.of(section);
    return MaterialApp(
      title: 'ريڤال ستوديو',
      debugShowCheckedModeBanner: false,
      theme: brand.theme(),
      darkTheme: brand.night.theme(),
      themeAnimationDuration: const Duration(milliseconds: 450),
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
          child: StudioHome(key: ValueKey(section)),
        ),
      ),
    );
  }
}
