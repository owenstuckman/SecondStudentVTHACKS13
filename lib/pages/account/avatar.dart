import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:octo_image/octo_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// in project
import '../../globals/database.dart';
import '../../globals/static/custom_widgets/icon_circle.dart';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';

class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onUpload,
    this.edit = true
  });

  final String? imageUrl;
  final void Function(String) onUpload;
  final bool edit;

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
            const IconCircle(
                color: Colors.grey,
                icon: Icons.account_circle_rounded,
                radius: 75)
          else
            ClipOval(
              child: OctoImage(
                image: NetworkImage(widget.imageUrl!),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorBuilder: (context, url, error) => Container(
                  width: 150,
                  height: 150,
                  color: colorScheme.secondary,
                  child: const Center(
                    child: Text('No Image'),
                  ),
                ),
              ),
            ),
          if(widget.edit)
          Align(
            alignment: Alignment.topRight,
            child: IconCircle(
                color: colorScheme.primary,
                padding: 10,
                radius: 20,
                iconColor: colorScheme.onPrimary,
                icon: Icons.edit,
                onPressed: _isLoading ? null : _upload),
          )
        ],
      ),
    );
  }

  Future<void> _upload() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (imageFile == null) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = fileName;
      await supabase.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: imageFile.mimeType),
          );
      final imageUrlResponse = await supabase.storage
          .from('avatars')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);
      final id = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrlResponse}).eq('id', id);

      widget.onUpload(imageUrlResponse);
    } on StorageException catch (error) {
      if (mounted) {
        context.showSnackBar(error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Unexpected error occurred', isError: true);
      }
    }

    setState(() => _isLoading = false);
  }
}
