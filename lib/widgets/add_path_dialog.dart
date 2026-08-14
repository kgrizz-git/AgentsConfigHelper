import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// A dialog that prompts the user for an absolute filesystem path.
///
/// Pops with the trimmed path string on confirm, or null on cancel.
class AddPathDialog extends StatefulWidget {
  /// Creates the dialog.
  const AddPathDialog({required this.title, required this.hintText, super.key});

  /// The dialog title.
  final String title;

  /// Placeholder text shown in the empty text field.
  final String hintText;

  @override
  State<AddPathDialog> createState() => _AddPathDialogState();
}

class _AddPathDialogState extends State<AddPathDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: Text(widget.title, style: AppTextStyles.uiHeader),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppTextStyles.codeBase,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTextStyles.uiSecondary,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
