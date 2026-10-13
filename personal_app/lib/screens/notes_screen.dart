import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

const _categories = ['سيناريو', 'حملة', 'لقطة', 'تطبيق', 'برتي ليدي', 'عام'];

class Note {
  String text, category;
  final int created;
  Note(this.text, this.category, this.created);

  Map<String, dynamic> toJson() => {
    'text': text,
    'category': category,
    'created': created,
  };
  factory Note.fromJson(Map<String, dynamic> j) =>
      Note(j['text'] as String, j['category'] as String, j['created'] as int);
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static const _key = 'notes';
  List<Note> _notes = [];
  String? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    setState(() {
      _notes = (jsonDecode(raw) as List)
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_notes));
  }

  Future<void> _edit([Note? note]) async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      builder: (_) => _NoteSheet(
        text: note?.text ?? '',
        category: note?.category ?? _filter ?? 'عام',
      ),
    );
    if (result == null) return;
    final (value, category) = result;
    setState(() {
      if (note == null) {
        _notes.insert(
          0,
          Note(value, category, DateTime.now().millisecondsSinceEpoch),
        );
      } else {
        note
          ..text = value
          ..category = category;
      }
    });
    await _save();
  }

  Future<void> _delete(Note note) async {
    final index = _notes.indexOf(note);
    setState(() => _notes.remove(note));
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('انمسحت الفكرة'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            setState(() => _notes.insert(index, note));
            _save();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filter == null
        ? _notes
        : _notes.where((n) => n.category == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('دفتر الأفكار')),
      floatingActionButton: FloatingActionButton(
        onPressed: _edit,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final c in [null, ..._categories])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(c ?? 'الكل'),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      'ماكو أفكار بعد. اضغط + وسجّل أول فكرة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = shown[i];
                      final d = DateTime.fromMillisecondsSinceEpoch(n.created);
                      return Dismissible(
                        key: ValueKey(n.created),
                        onDismissed: (_) => _delete(n),
                        background: Container(
                          decoration: BoxDecoration(
                            color: kRed.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Card(
                          child: ListTile(
                            onTap: () => _edit(n),
                            title: Text(
                              n.text,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${n.category} · ${d.day}/${d.month}/${d.year}',
                                style: const TextStyle(color: kGold),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  final String text, category;
  const _NoteSheet({required this.text, required this.category});

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _text = TextEditingController(text: widget.text);
  late String _category = widget.category;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.text.trim();
    Navigator.pop(context, value.isEmpty ? null : (value, _category));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(hintText: 'اكتب فكرتك...'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('حفظ')),
          ),
        ],
      ),
    );
  }
}
