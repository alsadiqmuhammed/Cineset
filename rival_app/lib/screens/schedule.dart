import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'patient_screen.dart'
    show birthdayText, callPhone, openWhatsApp, reminderText;

/// يختار تاريخ وساعة (الساعة اختيارية) لموعد الحالة. يرجع null إذا انلغى.
Future<int?> pickAppointment(BuildContext context, CaseRecord c) async {
  final now = DateTime.now();
  final first = DateTime(now.year - 1);
  final last = DateTime(now.year + 3);
  var init = c.nextVisit == null
      ? now.add(const Duration(days: 7))
      : DateTime.fromMillisecondsSinceEpoch(c.nextVisit!);
  if (init.isBefore(first)) init = first;
  if (init.isAfter(last)) init = last;
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first,
    lastDate: last,
    helpText: 'يوم الموعد',
  );
  if (d == null || !context.mounted) return null;
  final old = c.nextVisit == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(c.nextVisit!);
  final t = await showTimePicker(
    context: context,
    helpText: 'الساعة (اختياري)',
    cancelText: 'بدون ساعة',
    initialTime: old == null || (old.hour == 0 && old.minute == 0)
        ? const TimeOfDay(hour: 17, minute: 0)
        : TimeOfDay.fromDateTime(old),
  );
  return DateTime(
    d.year,
    d.month,
    d.day,
    t?.hour ?? 0,
    t?.minute ?? 0,
  ).millisecondsSinceEpoch;
}

/// المراجع إجه: تنسجل زيارة اليوم وينغلق الموعد، وبعدها يكدر يحدد الجاي.
Future<void> markAttended(BuildContext context, CaseRecord c) async {
  final b = context.brand;
  final now = DateTime.now();
  c.visits
    ..add(
      Visit(
        id: Store.newId(),
        date: now.millisecondsSinceEpoch,
        note: b.f('مراجعة حسب الموعد', 'جلسة حسب الموعد'),
      ),
    )
    ..sort((a, b) => a.date.compareTo(b.date));
  c.nextVisit = null;
  await Store.instance.save();
  if (!context.mounted) return;
  final again = await confirm(
    context,
    'انسجلت الزيارة ✓',
    'تحدد الموعد الجاي هسه؟',
    action: 'حدد موعد',
  );
  if (!again || !context.mounted) return;
  final next = await pickAppointment(context, c);
  if (next == null) return;
  c.nextVisit = next;
  await Store.instance.save();
}

Future<void> reschedule(BuildContext context, CaseRecord c) async {
  final next = await pickAppointment(context, c);
  if (next == null) return;
  c.nextVisit = next;
  await Store.instance.save();
}

/// إجراءات سريعة على موعد.
Future<void> showAppointmentActions(
  BuildContext context,
  Patient p,
  CaseRecord c,
) {
  final b = context.brand;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      Widget item(IconData icon, String text, Color color, VoidCallback f) =>
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            title: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () {
              Navigator.pop(sheet);
              f();
            },
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: b.text,
                ),
              ),
              Text(
                '${c.title} · ${arDateTime(c.nextVisit!)}',
                style: TextStyle(color: b.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              item(
                Icons.check_circle_outline,
                b.f('إجه · سجّل الزيارة', 'إجت · سجّلي الجلسة'),
                const Color(0xFF2E9E5B),
                () => markAttended(context, c),
              ),
              item(
                Icons.update,
                b.f('أجّل أو غيّر الموعد', 'أجّلي أو غيّري الموعد'),
                b.highlight,
                () => reschedule(context, c),
              ),
              if (p.phone.trim().isNotEmpty) ...[
                item(
                  Icons.chat_outlined,
                  'تذكير بالواتساب',
                  const Color(0xFF2E7D4F),
                  () => openWhatsApp(p.phone, text: reminderText(b, p, c)),
                ),
                item(
                  Icons.call_outlined,
                  'اتصال',
                  b.primary,
                  () => callPhone(p.phone),
                ),
              ],
              item(
                Icons.event_busy_outlined,
                'إلغاء الموعد',
                b.muted,
                () async {
                  c.nextVisit = null;
                  await Store.instance.save();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// المراجعين اللي عيد ميلادهم خلال [days] يوم (اليوم أولاً).
List<(Patient, int)> upcomingBirthdays(Store store, {int days = 30}) {
  final now = DateTime.now();
  return [
    for (final p in store.patients)
      if (p.daysToBirthday(now) case final d? when d <= days) (p, d),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
}

/// بطاقة عيد ميلاد: كم باقي، العمر الجاي، وتهنئة واتساب بضغطة.
class BirthdayTile extends StatelessWidget {
  final Patient p;
  final int days;
  const BirthdayTile(this.p, this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final today = days == 0;
    final d = p.birthday!;
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: today
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [b.accent, b.highlight],
                    )
                  : null,
              color: today ? null : b.accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.cake_rounded,
              color: today ? Colors.white : b.highlight,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: b.text),
                ),
                Text(
                  [
                    today
                        ? (p.gender == Gender.female || b.feminine
                              ? 'عيد ميلادها اليوم'
                              : 'عيد ميلاده اليوم')
                        : days == 1
                        ? 'باچر'
                        : 'بعد ${ar(days)} يوم',
                    '${ar(d.day)} ${arMonths[d.month - 1]}',
                    if (p.turning != null) 'يكمل ${ar(p.turning!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: b.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (p.phone.trim().isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () => openWhatsApp(p.phone, text: birthdayText(b, p)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: today
                    ? b.primary
                    : b.primary.withValues(alpha: 0.1),
                foregroundColor: today ? Colors.white : b.primary,
              ),
              icon: const Icon(Icons.chat_outlined, size: 17),
              label: const Text('هنّئ'),
            ),
        ],
      ),
    );
  }
}
