import 'package:flutter/material.dart';

import '../brand.dart';
import '../cloud.dart';
import 'common.dart';

/// إدارة حسابات الدخول (للإدارة بس): حساب لكل طبيب مربوط بملفه،
/// فيشوف حالاته بس. حساب "إدارة" يشوف كل شي.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final me = Cloud.instance.user?.email?.toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('حسابات الدخول')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('حساب جديد'),
      ),
      body: StreamBuilder<List<Member>>(
        stream: Cloud.instance.watchMembers(),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'ما گدرنا نقرا الحسابات',
              body: 'تأكد إنك ناشر قواعد firestore.rules الجديدة.',
            );
          }
          final list = snap.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'كل طبيب يدخل بحسابه ويشوف بس حالاته والمراجعين اللي عنده حالات وياهم. '
                'حساب الإدارة يشوف كل شي ويدير الحسابات.',
                style: TextStyle(color: b.muted, height: 1.6),
              ),
              const SizedBox(height: 14),
              for (final m in list) ...[
                BrandCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => _edit(context, m),
                    leading: CircleAvatar(
                      backgroundColor: m.isAdmin ? b.dark : b.primary,
                      child: Icon(
                        m.isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      m.name.isEmpty ? m.email : m.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        m.email,
                        if (m.isAdmin) 'إدارة' else 'طبيب',
                        if (m.email == me) 'حسابك',
                      ].join(' · '),
                      style: TextStyle(color: b.muted, fontSize: 12),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                    ),
                    trailing: const Icon(Icons.chevron_left),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, Member? m) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MemberSheet(existing: m),
  );
}

class _MemberSheet extends StatefulWidget {
  final Member? existing;
  const _MemberSheet({this.existing});

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _name = TextEditingController(text: widget.existing?.name);
  final _password = TextEditingController();
  late bool _admin = widget.existing?.isAdmin ?? false;
  late final Map<String, String?> _doctor = {
    'dental': widget.existing?.doctorFor('dental'),
    'beauty': widget.existing?.doctorFor('beauty'),
  };
  final Map<String, List<(String, String)>> _options = {};
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.existing == null;
  bool get _isMe =>
      widget.existing?.email == Cloud.instance.user?.email?.toLowerCase();

  @override
  void initState() {
    super.initState();
    for (final s in const ['dental', 'beauty']) {
      Cloud.instance
          .doctorsOf(s)
          .then((l) {
            if (mounted) setState(() => _options[s] = l);
          })
          .catchError((_) {
            if (mounted) setState(() => _options[s] = const []);
          });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'اكتب إيميل صحيح');
      return;
    }
    if (_isNew && _password.text.length < 6) {
      setState(() => _error = 'الرمز لازم يكون ٦ أحرف أو أكثر');
      return;
    }
    final ids = {
      for (final e in _doctor.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (!_admin && ids.isEmpty) {
      setState(() => _error = 'اربط الحساب بملف طبيب بقسم واحد على الأقل');
      return;
    }
    if (_isMe && !_admin) {
      setState(() => _error = 'ما تگدر تشيل صلاحية الإدارة من حسابك');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Cloud.instance.saveMember(
      Member(
        email: email,
        name: _name.text.trim(),
        isAdmin: _admin,
        doctorIds: ids,
      ),
      password: _isNew ? _password.text : null,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context);
    toast(context, _isNew ? 'انضاف الحساب' : 'انحفظت الصلاحيات');
  }

  Future<void> _remove() async {
    final m = widget.existing!;
    final ok = await confirm(
      context,
      'حذف حساب ${m.name.isEmpty ? m.email : m.name}؟',
      'ما يگدر يدخل بعد على بيانات العيادة. حالاته تبقى.',
    );
    if (!ok) return;
    await Cloud.instance.removeMember(m.email);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reset() async {
    final err = await Cloud.instance.sendPasswordReset(widget.existing!.email);
    if (mounted) {
      toast(context, err ?? 'انرسل رابط تغيير الرمز لإيميله');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    Widget doctorPicker(String section, String label) {
      final opts = _options[section];
      return DropdownButtonFormField<String?>(
        initialValue: _doctor[section],
        isExpanded: true,
        decoration: InputDecoration(labelText: 'ملفه بـ $label'),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('ماكو (ما يفتح القسم)'),
          ),
          for (final (id, name) in opts ?? const <(String, String)>[])
            DropdownMenuItem(value: id, child: Text(name)),
          if (_doctor[section] != null &&
              !(opts ?? const []).any((o) => o.$1 == _doctor[section]))
            DropdownMenuItem(
              value: _doctor[section],
              child: Text(_doctor[section]!),
            ),
        ],
        onChanged: opts == null
            ? null
            : (v) => setState(() => _doctor[section] = v),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? 'حساب جديد' : 'صلاحيات الحساب',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              enabled: _isNew,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'الإيميل'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            if (_isNew) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رمز الدخول',
                  helperText: 'سلّمه للطبيب، ويگدر يغيره بعدين',
                ),
              ),
            ],
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('طبيب'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('إدارة'),
                  icon: Icon(Icons.admin_panel_settings),
                ),
              ],
              selected: {_admin},
              onSelectionChanged: (s) => setState(() => _admin = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _admin
                  ? 'يشوف كل المراجعين والحالات بالقسمين، ويدير الحسابات.'
                  : 'يشوف بس حالاته، والمراجعين اللي عنده حالات وياهم.',
              style: TextStyle(color: b.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            doctorPicker('dental', 'الأسنان'),
            const SizedBox(height: 10),
            doctorPicker('beauty', 'التجميل'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(_isNew ? 'إنشاء الحساب' : 'حفظ'),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.lock_reset),
                label: const Text('إرسال رابط تغيير الرمز'),
              ),
              if (!_isMe)
                TextButton.icon(
                  onPressed: _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف الحساب'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB3261E),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
