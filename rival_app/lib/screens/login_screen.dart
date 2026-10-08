import 'package:flutter/material.dart';

import '../cloud.dart';
import '../store.dart';

/// الدخول لقاعدة البيانات الموحدة بحساب العيادة.
/// كل الأجهزة اللي تدخل بحسابات العيادة تشوف نفس المراجعين والحالات والصور.
class LoginScreen extends StatefulWidget {
  /// بعد الدخول أو اختيار "بدون حساب".
  final VoidCallback onDone;

  /// من "المزيد": يرجع بدل ما يكمل للتطبيق.
  final bool fromSettings;
  const LoginScreen({
    super.key,
    required this.onDone,
    this.fromSettings = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'اكتب الإيميل والرمز');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Cloud.instance.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    await Store.instance.setCloudSkipped(false);
    widget.onDone();
  }

  Future<void> _skip() async {
    await Store.instance.setCloudSkipped(true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF231F20), soft = Color(0xFF6B5F57);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      appBar: widget.fromSettings
          ? AppBar(backgroundColor: const Color(0xFFF4F1EC))
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            Center(child: Image.asset('assets/brand/symbol.png', height: 84)),
            const SizedBox(height: 22),
            const Text(
              'حساب العيادة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ادخل حتى تشتغل كل أجهزة العيادة على نفس الأرشيف. التعديلات تتزامن لحالها، وتنحفظ حتى بدون إنترنت.',
              textAlign: TextAlign.center,
              style: TextStyle(color: soft, height: 1.6),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'الإيميل',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _signIn(),
              decoration: InputDecoration(
                labelText: 'الرمز',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('دخول'),
            ),
            if (!widget.fromSettings) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: const Text(
                  'استخدم بدون حساب (بيانات هذا الجهاز بس)',
                  style: TextStyle(color: soft),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'الحسابات يضيفها مسؤول العيادة. إذا ما عندك حساب، اطلبه منه.',
              textAlign: TextAlign.center,
              style: TextStyle(color: soft, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
