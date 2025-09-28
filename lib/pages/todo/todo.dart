import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:uuid/uuid.dart';
import 'package:secondstudent/globals/static/extensions/local-storage-wrap.dart';
import 'package:secondstudent/globals/static/custom_widgets/styled_button.dart';
import 'package:secondstudent/globals/static/types/to-do.dart';

class ToDo extends StatefulWidget {
  const ToDo({super.key});

  @override
  State<ToDo> createState() => _ToDoState();
}

final uuid = Uuid();

class _ToDoState extends State<ToDo> {
  final List<ToDoItem> _todos = [];
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _loadFromStorage() {
    final stored = localStorage.getItem('todos');
    if (stored == null || stored.isEmpty) return;
    try {
      final List<dynamic> list = jsonDecode(stored) as List<dynamic>;
      final loaded = list.whereType<Map>().map((e) {
        final dynamic rawId = e['id'];
        final int id = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '') ??
                  DateTime.now().millisecondsSinceEpoch;
        return ToDoItem(
          id: id,
          title: (e['title'] ?? '').toString(),
          checked: e['checked'] == true,
          dueAt: (e['dueAt'] ?? '').toString(),
        );
      }).toList();
      if (loaded.isNotEmpty) {
        setState(() => _todos.addAll(loaded));
      }
    } catch (_) {}
  }

  void _saveToStorage() {
    final jsonList = _todos
        .map(
          (t) => {
            'id': t.id,
            'title': t.title,
            'checked': t.checked,
            'dueAt': t.dueAt,
          },
        )
        .toList();
    localStorage.inclusiveSetItem('todos', jsonEncode(jsonList));
  }

  void _addTodo({required String title, required DateTime? due}) {
    final item = ToDoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title.isEmpty ? 'New To-Do' : title,
      checked: false,
      dueAt: due?.toIso8601String() ?? '',
    );
    setState(() => _todos.add(item));
    _saveToStorage();
    Navigator.of(context).pop();
  }

  void _toggleChecked(ToDoItem item, bool value) {
    final idx = _todos.indexOf(item);
    if (idx == -1) return;
    setState(
      () => _todos[idx] = ToDoItem(
        id: item.id,
        title: item.title,
        checked: value,
        dueAt: item.dueAt,
      ),
    );
    _saveToStorage();
  }

  void _delete(ToDoItem item) {
    setState(() => _todos.removeWhere((t) => t.id == item.id));
    deleteItem('todos', item.id.toString());
  }

  Widget _dialogBuilder() {
    final DateTime displayDate = _selectedDate ?? DateTime.now();
    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.28,
        width: MediaQuery.of(context).size.width * 0.30,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: displayDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'To-Do Title',
                  ),
                ),
                const SizedBox(height: 12),
                StyledButton(
                  text: 'Add To-Do',
                  onTap: () {
                    _addTodo(
                      title: _titleController.text.trim(),
                      due: _selectedDate,
                    );
                    _titleController.clear();
                    _selectedDate = null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('To-Do')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _todos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _todos[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _delete(item),
                  icon: Icon(Icons.remove_circle, color: Colors.red),
                ),
                Expanded(
                  child: CheckboxListTile(
                    value: item.checked,
                    onChanged: (v) => _toggleChecked(item, v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item.title),
                    subtitle: item.dueAt.isNotEmpty
                        ? Text(
                            'Due: ${DateTime.tryParse(item.dueAt)?.toLocal().toString() ?? item.dueAt}',
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        onPressed: () =>
            showDialog(context: context, builder: (_) => _dialogBuilder()),
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
    );
  }
}
