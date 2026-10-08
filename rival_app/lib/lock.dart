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
    } catch (_) {
      // إذا التلفون بدون قفل شاشة، ما نحبس الطبيب برّه التطبيق.
      if (mounted) setState(() => _locked = false);
    } finally {
      _authing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final b = context.brand;
    return Scaffold(
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
