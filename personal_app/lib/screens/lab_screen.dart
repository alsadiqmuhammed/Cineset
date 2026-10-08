import 'package:flutter/material.dart';

import '../theme.dart';

class _Analyte {
  final String name, conv, si;
  final double Function(double) toSi, fromSi;
  const _Analyte(this.name, this.conv, this.si, this.toSi, this.fromSi);
}

final _analytes = [
  _Analyte('Glucose', 'mg/dL', 'mmol/L', (v) => v / 18.016, (v) => v * 18.016),
  _Analyte(
    'Cholesterol',
    'mg/dL',
    'mmol/L',
    (v) => v / 38.67,
    (v) => v * 38.67,
  ),
  _Analyte(
    'Triglycerides',
    'mg/dL',
    'mmol/L',
    (v) => v / 88.57,
    (v) => v * 88.57,
  ),
  _Analyte('Creatinine', 'mg/dL', 'µmol/L', (v) => v * 88.4, (v) => v / 88.4),
  _Analyte('Urea', 'mg/dL', 'mmol/L', (v) => v / 6.006, (v) => v * 6.006),
  _Analyte('BUN', 'mg/dL', 'mmol/L urea', (v) => v * 0.357, (v) => v / 0.357),
  _Analyte('Uric acid', 'mg/dL', 'µmol/L', (v) => v * 59.48, (v) => v / 59.48),
  _Analyte('Bilirubin', 'mg/dL', 'µmol/L', (v) => v * 17.1, (v) => v / 17.1),
  _Analyte('Calcium', 'mg/dL', 'mmol/L', (v) => v * 0.2495, (v) => v / 0.2495),
  _Analyte('Hemoglobin', 'g/dL', 'g/L', (v) => v * 10, (v) => v / 10),
  _Analyte(
    'HbA1c',
    '% (NGSP)',
    'mmol/mol (IFCC)',
    (v) => (v - 2.15) * 10.929,
    (v) => v / 10.929 + 2.15,
  ),
];

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});
  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  int _index = 0;
  bool _toSi = true;
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _analytes[_index];
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    final result = v == null ? null : (_toSi ? a.toSi(v) : a.fromSi(v));
    final from = _toSi ? a.conv : a.si, to = _toSi ? a.si : a.conv;
    return Scaffold(
      appBar: AppBar(title: const Text('المختبر — تحويل الوحدات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _analytes.length; i++)
                ChoiceChip(
                  label: Text(_analytes[i].name),
                  selected: _index == i,
                  onSelected: (_) => setState(() => _index = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                labelText: '${a.name} ($from)',
                suffixIcon: IconButton(
                  tooltip: 'اقلب الاتجاه',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: () => setState(() => _toSi = !_toSi),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    result == null ? '—' : result.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: kGold,
                    ),
                  ),
                  Text(to, textDirection: TextDirection.ltr),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'معاملات التحويل القياسية. راجع دليل جهازك وكيتاتك للقيم المرجعية.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
