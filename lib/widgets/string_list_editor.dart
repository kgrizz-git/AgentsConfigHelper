import 'package:flutter/material.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';

class StringListEditor extends StatefulWidget {
  const StringListEditor({
    super.key,
    required this.values,
    required this.onChanged,
    required this.hintText,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String hintText;

  @override
  State<StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<StringListEditor> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant StringListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.values != oldWidget.values) {
      // Re-init controllers if the underlying values were reset externally
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    _controllers = widget.values.map((v) => TextEditingController(text: v)).toList();
  }

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(_controllers.map((c) => c.text).toList());
  }

  void _addField() {
    setState(() {
      _controllers.add(TextEditingController());
      _notifyChanged();
    });
  }

  void _removeField(int index) {
    setState(() {
      final c = _controllers.removeAt(index);
      c.dispose();
      _notifyChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: (_) => _notifyChanged(),
                    style: AppTextStyles.codeBase,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: AppTextStyles.uiSecondary,
                      filled: true,
                      fillColor: AppColors.sidebarDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                  onPressed: () => _removeField(index),
                  tooltip: 'Remove',
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _addField,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Item'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryAccent,
            textStyle: AppTextStyles.uiBase,
          ),
        ),
      ],
    );
  }
}
