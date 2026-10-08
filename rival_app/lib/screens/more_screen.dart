import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../main.dart';
import '../store.dart';
import 'common.dart';
import 'design_controls.dart';
import 'doctor_profile_screen.dart';
import 'doctors_screen.dart';
import 'overlays_screen.dart';
import 'patient_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _backup(BuildContext context) async {
    try {
      final path = await Store.instance.exportBackup();
      await shareFile(path);
    } catch (e) {
      if (context.mounted) toast(context, 'ما تمت النسخة: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = files.isEmpty ? null : files.first.path;
    if (path == null || !context.mounted) return;
    final ok = await confirm(
      context,
      'استرجاع النسخة؟',
      'راح تتبدل كل البيانات الحالية (القسمين) بمحتوى النسخة.',
      action: 'استرجاع',
    );
    if (!ok) return;
    try {
      await Store.instance.restoreBackup(path);
      if (context.mounted) toast(context, 'تم الاسترجاع');
    } catch (e) {
      if (context.mounted) toast(context, 'ما تم الاسترجاع: $e');
    }
  }

  Future<void> _toggleLock(BuildContext context, bool v) async {
    if (v) {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        if (context.mounted) {
          toast(context, 'فعّل قفل الشاشة بالتلفون أولاً (بصمة أو رمز).');
        }
        return;
      }
      final ok = await auth.authenticate(localizedReason: 'تفعيل قفل التطبيق');
      if (!ok) return;
    }
    await Store.instance.setLock(v);
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final me = store.activeDoctor;
        final other = b.section == Section.dental ? beauty : dental;
        return Scaffold(
          appBar: AppBar(
            title: const Text('المزيد'),
            actions: const [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 12),
                child: SectionSwitch(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              BrandCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Image.asset(b.logoPrimary, height: 96),
                    const SizedBox(height: 14),
                    _ContactLine(
                      Icons.location_on_outlined,
                      store.clinic.address,
                    ),
                    _ContactLine(Icons.schedule, store.clinic.hours),
                    for (final p in store.clinic.phones)
                      _ContactLine(
                        Icons.call_outlined,
                        p,
                        ltr: true,
                        actions: [
                          IconButton(
                            onPressed: () => callPhone(p),
                            icon: Icon(Icons.call, color: b.primary, size: 20),
                          ),
                          IconButton(
                            onPressed: () => openWhatsApp(p),
                            icon: Icon(Icons.chat, color: b.primary, size: 20),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${b.latinName} ${store.clinic.address}')}',
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('الخريطة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const _ClinicSheet(),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionHeader('الفريق'),
              _Tile(
                Icons.account_circle_outlined,
                me == null ? 'اختار ملفك الشخصي' : 'ملفي: ${me.name}',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => me == null
                        ? const DoctorsScreen(pickMe: true)
                        : DoctorProfileScreen(doctor: me),
                  ),
                ),
              ),
              _Tile(
                Icons.badge_outlined,
                'الأطباء (${ar(store.doctors.length)})',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorsScreen()),
                ),
              ),
              SectionHeader('التصاميم'),
              _Tile(
                Icons.filter_frames_outlined,
                'قوالب PNG (${ar(store.overlays.length)})',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OverlaysScreen()),
                ),
              ),
              SectionHeader('البيانات والخصوصية'),
              _Tile(
                Icons.cloud_upload_outlined,
                'نسخة احتياطية (القسمين)',
                () => _backup(context),
                subtitle: 'ملف zip بكل المراجعين والصور. احفظه بمكان آمن.',
              ),
              _Tile(
                Icons.settings_backup_restore,
                'استرجاع نسخة',
                () => _restore(context),
              ),
              BrandCard(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  value: store.lockEnabled,
                  onChanged: (v) => _toggleLock(context, v),
                  secondary: Icon(Icons.fingerprint, color: b.primary),
                  title: const Text(
                    'قفل التطبيق',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'بالبصمة أو رمز التلفون، لحماية صور المراجعين',
                    style: TextStyle(color: b.muted, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  gradient: other.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: b.shadow,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => RivalApp.of(context).switchSection(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Image.asset(other.logoReversed, height: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'انتقل لـ ${other.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(Icons.swap_horiz, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '${b.latinName} · البيانات محفوظة على هذا التلفون فقط',
                  style: TextStyle(color: b.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.onTap, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrandCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: b.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: b.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(color: b.muted, fontSize: 12),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: b.muted),
          ],
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool ltr;
  final List<Widget> actions;
  const _ContactLine(
    this.icon,
    this.text, {
    this.ltr = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: b.highlight, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: ltr ? TextAlign.right : null,
              style: TextStyle(
                color: b.text,
                fontWeight: ltr ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _ClinicSheet extends StatefulWidget {
  const _ClinicSheet();
  @override
  State<_ClinicSheet> createState() => _ClinicSheetState();
}

class _ClinicSheetState extends State<_ClinicSheet> {
  final c = Store.instance.clinic;
  late final _address = TextEditingController(text: c.address);
  late final _hours = TextEditingController(text: c.hours);
  late final _phones = TextEditingController(text: c.phones.join('\n'));

  @override
  void dispose() {
    _address.dispose();
    _hours.dispose();
    _phones.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'معلومات العيادة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'العنوان'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hours,
            decoration: const InputDecoration(labelText: 'الدوام'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phones,
            minLines: 2,
            maxLines: 4,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'أرقام الهاتف (كل رقم بسطر)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              c
                ..address = _address.text.trim()
                ..hours = _hours.text.trim()
                ..phones = _phones.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              await Store.instance.saveAll();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
