// lib/pages/editor/file.dart
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:secondstudent/globals/static/extensions/canvasFullQuery.dart';

class FilePage extends StatefulWidget {
  final int courseId;

  const FilePage({super.key, required this.courseId});

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  List<dynamic> files = [];
  List<dynamic> folders = [];
  late Map<int, Map<String, dynamic>> folderMap;
  late List<Map<String, dynamic>> topLevelFolders;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCourseContent();
  }

  Future<void> loadCourseContent() async {
    final domain = localStorage.getItem('canvasDomain');
    final token = localStorage.getItem('canvasToken');

    if (domain == null || token == null) {
      setState(() => isLoading = false);
      return;
    }

    final headers = {'Authorization': 'Bearer $token'};

    try {
      final filesUri = Uri.parse(
        '$domain/api/v1/courses/${widget.courseId}/files?per_page=100',
      );
      final foldersUri = Uri.parse(
        '$domain/api/v1/courses/${widget.courseId}/folders?per_page=100',
      );

      final fetchedFiles = await CanvasFullQuery.fetchAllPages(
        filesUri,
        headers,
      );
      final fetchedFolders = await CanvasFullQuery.fetchAllPages(
        foldersUri,
        headers,
      );

      // Build folder hierarchy
      folderMap = {
        for (var f in fetchedFolders)
          f['id'] as int: {
            ...f,
            'subfolders': <Map<String, dynamic>>[],
            'files': <Map<String, dynamic>>[],
          },
      };

      // Attach subfolders to parents
      for (var f in fetchedFolders) {
        final parentId = f['parent_folder_id'];
        if (parentId != null && folderMap.containsKey(parentId)) {
          folderMap[parentId]!['subfolders'].add(folderMap[f['id']]!);
        }
      }

      // Attach files to their folders
      for (var file in fetchedFiles) {
        final fid = file['folder_id'];
        if (fid != null && folderMap.containsKey(fid)) {
          folderMap[fid]!['files'].add(file);
        }
      }

      topLevelFolders = folderMap.values
          .where((f) => f['parent_folder_id'] == null)
          .toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Course ${widget.courseId}')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [...topLevelFolders.map(_buildFolderTile).toList()],
            ),
    );
  }

  Widget _buildFolderTile(Map<String, dynamic> folder) {
    final subfolders = folder['subfolders'] as List<Map<String, dynamic>>;
    final folderFiles = folder['files'] as List<dynamic>;

    return ExpansionTile(
      leading: const Icon(Icons.folder),
      title: Text(folder['name'] ?? 'Unnamed'),
      children: [
        ...subfolders.map(_buildFolderTile).toList(),
        ...folderFiles.map<Widget>(
          (f) => ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(f['display_name'] ?? 'Unnamed'),
            subtitle: Text('${(f['size'] ?? 0)} bytes'),
            onTap: () {
              final url = f['url'];
              if (url != null) {
                // TODO: open url
              }
            },
          ),
        ),
      ],
    );
  }
}
