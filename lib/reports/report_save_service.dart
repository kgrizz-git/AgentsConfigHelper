import 'dart:convert';
import 'dart:io';

import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signature for a native save-file dialog.
///
/// Returns the selected path, or null if the user cancels.
typedef SaveFileDialog = Future<String?> Function(
  String suggestedName,
  String? acceptedExtension,
);

/// Provides the platform save-file dialog.
///
/// Tests override this with a stub that returns a fixed path or null.
final saveFileDialogProvider = Provider<SaveFileDialog>((ref) {
  return (suggestedName, acceptedExtension) async {
    final result = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: acceptedExtension == null
          ? const <XTypeGroup>[]
          : [
              XTypeGroup(extensions: [acceptedExtension]),
            ],
    );
    return result?.path;
  };
});

/// Service for saving config overview reports to disk.
class ReportSaveService {
  /// Creates a report save service.
  const ReportSaveService({required this.saveFileDialog});

  /// The dialog used to ask the user where to save.
  final SaveFileDialog saveFileDialog;

  /// Saves a Markdown report, returning true on success.
  Future<bool> saveMarkdown(List<ConfigOverviewEntry> entries) async {
    final content = buildMarkdownReport(entries);
    return _writeWithDialog(
      suggestedName: _defaultMarkdownName,
      extension: 'md',
      bytes: utf8.encode(content),
    );
  }

  /// Saves an HTML report, returning true on success.
  Future<bool> saveHtml(List<ConfigOverviewEntry> entries) async {
    final content = buildHtmlReport(entries);
    return _writeWithDialog(
      suggestedName: _defaultHtmlName,
      extension: 'html',
      bytes: utf8.encode(content),
    );
  }

  /// Writes [bytes] to the path returned by the dialog.
  ///
  /// Returns true if the file was written, false if the dialog was cancelled
  /// or the write failed.
  Future<bool> _writeWithDialog({
    required String suggestedName,
    required String extension,
    required List<int> bytes,
  }) async {
    final path = await saveFileDialog(suggestedName, extension);
    if (path == null) return false;
    try {
      final file = File(path);
      await file.writeAsBytes(bytes);
      return true;
    } on Exception catch (error) {
      throw Exception('Could not save report: $error');
    }
  }
}

const _defaultMarkdownName = 'config-overview-report.md';

const _defaultHtmlName = 'config-overview-report.html';
