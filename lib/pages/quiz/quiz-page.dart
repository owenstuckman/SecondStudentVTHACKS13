import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

/// Quick scaffold showing quiz groups retrieved from Supabase.
/// Tap a group to enter a (placeholder) quiz runner screen.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _future;
  final List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _future = _loadGroups();
  }

  Future<List<Map<String, dynamic>>> _loadGroups() async {
    final data = await _supabase.from('quizgroup').select('*').order('id');
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _createGroup() async {
    await _supabase.from('quizgroup').insert({'title': 'My Quiz'});
    setState(() => _future = _loadGroups());
  }

  Future<void> _renameGroup(Map<String, dynamic> group) async {
    final controller = TextEditingController(text: group['title']?.toString());
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Quiz'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await _supabase
          .from('quizgroup')
          .update({'title': newName})
          .eq('id', group['id']);
      setState(() => _future = _loadGroups());
    }
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: const Text('Are you sure you want to delete this quiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _supabase.from('quizgroup').delete().eq('id', group['id']);
      setState(() => _future = _loadGroups());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quizzes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return const Center(child: Text('No quizzes yet.'));
          }
          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final g = groups[index];
              return ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text(g['title']?.toString() ?? 'Quiz')),
                    PopupMenuButton<int>(
                      onSelected: (v) {
                        if (v == 0) _renameGroup(g);
                        if (v == 1) _deleteGroup(g);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 0, child: Text('Rename')),
                        const PopupMenuItem(value: 1, child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Placeholder: Navigate to quiz runner page later.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quiz runner not implemented'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'addQuizFiles',
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            onPressed: () async {
              final picked = await FilePicker.platform.pickFiles(
                allowMultiple: true,
              );
              if (picked == null || picked.files.isEmpty) return;
              setState(() => _selectedFiles.addAll(picked.files));
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'createQuiz',
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            onPressed: _selectedFiles.isEmpty
                ? null
                : () async {
                    try {
                      final response = await _supabase.functions.invoke(
                        'quizzes',
                        body: {
                          'paths': _selectedFiles.map((f) => f.path).toList(),
                        },
                      );
                      print(response.data);
                      setState(() {
                        _selectedFiles.clear();
                        _future = _loadGroups();
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quiz created')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
            child: const Icon(Icons.bolt),
          ),
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '${_selectedFiles.length}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurface),
              ),
            ),
        ],
      ),
    );
  }
}
