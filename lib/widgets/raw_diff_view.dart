import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Shows the before/after raw file content in the review dialog, truncating
/// each side to a preview of 20 lines until the user expands it.
class RawDiffView extends StatefulWidget {
  const RawDiffView({required this.original, required this.updated, super.key});

  final String original;
  final String updated;

  @override
  State<RawDiffView> createState() => _RawDiffViewState();
}

class _RawDiffViewState extends State<RawDiffView> {
  static const int _maxPreviewLines = 20;
  bool _showFull = false;

  bool get _isTruncated =>
      _lineCount(widget.original) > _maxPreviewLines ||
      _lineCount(widget.updated) > _maxPreviewLines;

  static int _lineCount(String text) => text.split('\n').length;

  String _displayText(String text) {
    if (text.isEmpty) return '(Empty)';
    if (_showFull) return text;
    final lines = text.split('\n');
    if (lines.length <= _maxPreviewLines) return text;
    final preview = lines.take(_maxPreviewLines).join('\n');
    return '$preview\n(${lines.length - _maxPreviewLines} more lines)';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Raw File Content',
          style: AppTextStyles.uiSubheader.copyWith(
            color: AppColors.primaryAccent,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black12,
            border: Border.all(color: AppColors.borderDark),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before:',
                style: AppTextStyles.uiSecondary.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _displayText(widget.original),
                style: AppTextStyles.codeBase.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppColors.borderDark),
              ),
              Text(
                'After:',
                style: AppTextStyles.uiSecondary.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _displayText(widget.updated),
                style: AppTextStyles.codeBase.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              if (_isTruncated) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showFull = !_showFull;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryAccent,
                  ),
                  child: Text(_showFull ? 'Show less' : 'Show full content'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
