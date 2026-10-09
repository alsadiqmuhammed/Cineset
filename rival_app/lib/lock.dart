import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'brand.dart';
import 'store.dart';

/// قفل اختياري (بصمة / وجه / رمز التلفون) لحماية صور وبيانات المراجعين.
/// يقفل عند التشغيل، وإذا رجع التطبيق بعد أكثر من دقيقة بالخلفية.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = Store.instance.lockEnabled;
  DateTime? _pausedAt;
  bool _authing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // أي كتابة ما انحفظت بعد تنحفظ قبل ما النظام يطفّي التطبيق.
    if (state == AppLifecycleState.paused) Store.instance.flush();
    if (!Store.instance.lockEnabled || _authing) return;
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away > const Duration(minutes: 1)) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    _authing = true;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'افتح تطبيق ريڤال',
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) setState(() => _locked = false);
    } on LocalAuthException catch (e) {
      // بس إذا التلفون ما بيه أي قفل شاشة ينفتح بدون تحقق. الإلغاء، الوقت،
      // والقفل المؤقت بعد محاولات غلط يخلّون التطبيق مقفول.
      if (e.code == LocalAuthExceptionCode.noCredentialsSet && mounted) {
        setState(() => _locked = false);
      }
    } catch (_) {
      // خطأ ثاني: يبقى مقفول، وزر "افتح التطبيق" يحاول مرة ثانية.
    } finally {
      _authing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // القفل طبقة فوق كل الشاشات المفتوحة (مو بس الرئيسية)، فلو رجع
    // للتطبيق وهو على صفحة حالة ما تبين الصور.
    return Stack(
      children: [
        Offstage(offstage: _locked, child: widget.child),
        if (_locked) Positioned.fill(child: _lockScreen(context)),
      ],
    );
  }

  Widget _lockScreen(BuildContext context) {
    final b = Store.instance.opened ? Store.instance.brand : dental;
    return Scaffold(
      backgroundColor: b.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(b.logoPrimary, height: 130),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _unlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('افتح التطبيق'),
            ),
          ],
        ),
      ),
    );
  }
}
