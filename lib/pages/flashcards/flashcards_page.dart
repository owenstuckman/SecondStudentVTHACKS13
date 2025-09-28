import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:localstorage/localstorage.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:secondstudent/pages/cardsPage/cardPage.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key});

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

Future<List<dynamic>> getFlashCardSets() async {
  final data = await supabase.from('flashcardgroup').select('*');

  print(data);
  return data;

  // supabase.functions.invoke('NoteCardProcess');
}

Future<List<dynamic>> getFlashCards() async {
  final data = await supabase
      .from('flashcard')
      .select('*')
      .eq('flashcardgroupid', '1');

  print(data);
  return data;

  // supabase.functions.invoke('NoteCardProcess');
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  final List<Map<String, dynamic>> _groups = [];
  final List<PlatformFile> _selectedFiles = [];

  Future<void> _renameGroup(Map<String, dynamic> group) async {
    final controller = TextEditingController(text: group['name']?.toString());
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
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
      setState(() {
        group['name'] = newName;
      });
      await _saveGroups();
    }
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Are you sure you want to delete this group?'),
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
      setState(() {
        _groups.remove(group);
      });
      await _saveGroups();
    }
  }

  Future<void> _loadGroups() async {
    final raw = localStorage.getItem('flashcard_groups');
    if (raw != null && raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _groups
          ..clear()
          ..addAll(decoded.cast<Map<String, dynamic>>());
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveGroups() async {
    localStorage.setItem('flashcard_groups', jsonEncode(_groups));
  }

  Future<void> _createGroupFromFile() async {
    // Pick any file; for now we just store its path and stub cards.
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path ?? '';
    if (path.isEmpty) return;

    // TODO: Call edge function to generate flashcards from file.
    // Placeholder stub: create fake card.
    final uuid = const Uuid().v4();
    final group = {
      'id': uuid,
      'name': result.files.single.name,
      'filePath': path,
      'cards': [
        {
          'question': 'Placeholder Q from ${result.files.single.name}',
          'answer': 'Placeholder answer',
        },
      ],
    };
    _groups.add(group);
    await _saveGroups();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget grid = _groups.isEmpty
        ? const Center(child: Text('No flashcard sets yet.'))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 4 / 3,
            ),
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final g = _groups[index];
              final cards = g['cards'] as List? ?? [];
              return GestureDetector(
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CardPage()));
                },
                child: Material(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                g['name']?.toString() ?? 'Group',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton<int>(
                              onSelected: (v) {
                                if (v == 0) {
                                  _renameGroup(g);
                                } else if (v == 1) {
                                  _deleteGroup(g);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 0,
                                  child: Text('Rename'),
                                ),
                                const PopupMenuItem(
                                  value: 1,
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${cards.length} card${cards.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: grid,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'addFiles',
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Files', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  final picked = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                  );
                  if (picked == null || picked.files.isEmpty) return;
                  setState(() => _selectedFiles.addAll(picked.files));
                },
              ),
              const SizedBox(width: 8),
              FloatingActionButton.extended(
                heroTag: 'createCards',
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Create', style: TextStyle(fontSize: 12)),
                onPressed: _selectedFiles.isEmpty
                    ? null
                    : () async {
                        try {
                          final response = await supabase.functions.invoke(
                            'NoteCardProcess',
                            body: {
                              'paths': _selectedFiles
                                  .map((f) => f.path)
                                  .toList(),
                            },
                          );
                          print(response.data);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Flashcards created!'),
                            ),
                          );
                          setState(() => _selectedFiles.clear());
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
              ),
            ],
          ),
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${_selectedFiles.length} file(s) selected',
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
