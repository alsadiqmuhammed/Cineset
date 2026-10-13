import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';

/// حساب الحالة: الكلفة المتفق عليها، الدفعات، والمتبقي.
class CaseMoneyCard extends StatelessWidget {
  final CaseRecord record;
  final VoidCallback onChanged;
  const CaseMoneyCard({
    super.key,
    required this.record,
    required this.onChanged,
  });

  Future<void> _price(BuildContext context) async {
    final v = await askAmount(
      context,
      title: 'كلفة العلاج',
      initial: record.price,
      allowClear: true,
    );
    if (v == null) return;
    record.price = v.$1;
    onChanged();
  }

  Future<void> _addPayment(BuildContext context) async {
    final due = record.due;
    final v = await askAmount(
      context,
      title: 'دفعة جديدة',
      suggestion: due != null && due > 0 ? due : null,
      withNote: true,
    );
    if (v == null || v.$1 == null || v.$1! <= 0) return;
    record.payments.add(
      Payment(
        id: Store.newId(),
        date: DateTime.now().millisecondsSinceEpoch,
        amount: v.$1!,
        note: v.$2,
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final c = record;
    final due = c.due;
    final settled = due != null && due <= 0 && c.price! > 0;
    Widget cell(String label, String value, {Color? color}) => Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color ?? b.text,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: b.muted, fontSize: 11.5)),
        ],
      ),
    );
    return BrandCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              cell(
                'الكلفة',
                c.price == null ? 'ما محددة' : money(c.price!),
                color: c.price == null ? b.muted : null,
              ),
              cell('المدفوع', money(c.paid), color: const Color(0xFF2E7D32)),
              cell(
                settled ? 'مسدّد' : 'المتبقي',
                due == null ? '—' : money(due < 0 ? 0 : due),
                color: settled
                    ? const Color(0xFF2E7D32)
                    : (due ?? 0) > 0
                    ? const Color(0xFFC62828)
                    : b.muted,
              ),
            ],
          ),
          if (c.price != null && c.price! > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (c.paid / c.price!).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: b.line,
                color: settled ? const Color(0xFF2E7D32) : b.primary,
              ),
            ),
          ],
          if (c.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final p in c.payments.reversed)
              Dismissible(
                key: ValueKey(p.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => confirm(
                  context,
                  'حذف الدفعة؟',
                  '${money(p.amount)} بتاريخ ${arDate(p.date)}',
                ),
                onDismissed: (_) {
                  c.payments.remove(p);
                  onChanged();
                },
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFFDECEA),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB3261E),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text(
                    money(p.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [arDate(p.date), if (p.note.isNotEmpty) p.note].join(' · '),
                    style: TextStyle(color: b.muted, fontSize: 12),
                  ),
                ),
              ),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _price(context),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: Text(c.price == null ? 'حدد الكلفة' : 'عدّل الكلفة'),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _addPayment(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('دفعة'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نافذة مبلغ (بأرقام عربية أو إنكليزية، ويقبل "٢٥٠ ألف").
/// ترجع (المبلغ أو null إذا انمسح، الملاحظة)، أو null إذا انلغت.
Future<(int?, String)?> askAmount(
  BuildContext context, {
  required String title,
  int? initial,
  int? suggestion,
  bool allowClear = false,
  bool withNote = false,
}) async {
  final amount = TextEditingController(text: initial == null ? '' : '$initial');
  final note = TextEditingController();
  final r = await showDialog<(int?, String)>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) {
          final parsed = parseAmount(amount.text);
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    labelText: 'المبلغ بالدينار',
                    hintText: 'مثلاً ٢٥٠٠٠٠ أو ٢٥٠ ألف',
                    helperText: parsed == null ? null : money(parsed),
                    errorText: error,
                  ),
                ),
                if (suggestion != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ActionChip(
                      label: Text('المتبقي كامل: ${money(suggestion)}'),
                      onPressed: () =>
                          setState(() => amount.text = '$suggestion'),
                    ),
                  ),
                ],
                if (withNote) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      hintText: 'نقداً، تحويل، الدفعة الأولى...',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (allowClear && initial != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, (null, '')),
                  child: const Text('شيل الكلفة'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final v = parseAmount(amount.text);
                  if (v == null) {
                    setState(() => error = 'اكتب المبلغ');
                    return;
                  }
                  Navigator.pop(ctx, (v, note.text.trim()));
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      );
    },
  );
  disposeLater([amount, note]);
  return r;
}
