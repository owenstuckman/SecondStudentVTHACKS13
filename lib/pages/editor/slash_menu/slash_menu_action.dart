import 'package:secondstudent/globals/database.dart';

enum SlashMenuAction {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  toDoList,
  divider,
  codeBlock,
  image,
  video,
  addEditNote,
  iframeExcalidraw,
  iframeGoogleDoc,
}

// Combine default actions with fetched extras
Future<List<SlashMenuAction>> fetchActionEnum() async {
  // Default actions
  final defaultActions = SlashMenuAction.values.toList();

  // Fetch extras from the database
  final rows = await supabase.from('blocks').select('quill_name');
  final actions = <SlashMenuAction>{};

  for (final row in rows) {
    final raw = row['quill_name'];
    final name = (raw is String ? raw : raw?.toString())?.trim();
    if (name == null || name.isEmpty) continue;

    try {
      actions.add(SlashMenuAction.values.byName(name));
    } catch (_) {
      print('fetchCombinedActions: unknown action "$name"');
    }
  }

  // Combine default actions with fetched extras and return a stable order
  final combinedActions = {...defaultActions, ...actions};
  return combinedActions.toList()..sort((a, b) => a.index.compareTo(b.index));
}
