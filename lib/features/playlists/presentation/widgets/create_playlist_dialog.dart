import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CreatePlaylistDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;

  const CreatePlaylistDialog({
    super.key,
    this.initialName,
    this.initialDescription,
  });

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;

    return AlertDialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing ? 'Rename Playlist' : 'New Playlist',
        style: const TextStyle(color: AppColors.textPrimaryDark),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle:
                  const TextStyle(color: AppColors.textSecondaryDark),
              hintText: 'My playlist',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondaryDark),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            style: const TextStyle(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle:
                  const TextStyle(color: AppColors.textSecondaryDark),
              hintText: 'Describe your playlist...',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondaryDark),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondaryDark)),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            final desc = _descController.text.trim();
            Navigator.of(context).pop((name: name, description: desc.isEmpty ? null : desc));
          },
          child: Text(
            isEditing ? 'Save' : 'Create',
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

Future<({String name, String? description})?> showCreatePlaylistDialog(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
}) async {
  final result = await showDialog<({String name, String? description})>(
    context: context,
    builder: (_) => CreatePlaylistDialog(
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
  return result;
}
