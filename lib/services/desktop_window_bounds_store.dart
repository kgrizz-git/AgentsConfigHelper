import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:agents_config_helper/services/file_operations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the last usable desktop window bounds as application preferences.
///
/// Test-root mode supplies a custom directory and file operations, keeping
/// these preferences below its disposable root instead of normal app support.
class DesktopWindowBoundsStore {
  /// Creates a store backed by [fileName] in the application support directory.
  DesktopWindowBoundsStore({
    Future<Directory> Function()? getDirectory,
    FileOperations? fileOperations,
    this.fileName = 'desktop_window_bounds.json',
  }) : _getDirectory = getDirectory ?? getApplicationSupportDirectory,
       _fileOperations = fileOperations ?? const LocalFileOperations();

  /// The JSON file name used below the configured support directory.
  final String fileName;
  final Future<Directory> Function() _getDirectory;
  final FileOperations _fileOperations;

  /// Loads valid saved bounds, or null when no usable saved bounds are present.
  Future<Rect?> load() async {
    try {
      final filePath = await _filePath();
      if (!await _fileOperations.fileExists(filePath)) return null;
      return decode(jsonDecode(await _fileOperations.readText(filePath)));
    } on Object {
      return null;
    }
  }

  /// Saves [bounds] when its position is finite and dimensions are positive.
  Future<void> save(Rect bounds) async {
    if (!isValid(bounds)) return;
    final content = const JsonEncoder.withIndent('  ').convert({
      'x': bounds.left,
      'y': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    });
    await _fileOperations.writeTextAtomically(await _filePath(), content);
  }

  /// Decodes a bounds object stored by this class, rejecting malformed values.
  static Rect? decode(Object? json) {
    if (json is! Map) return null;
    final x = _asFiniteDouble(json['x']);
    final y = _asFiniteDouble(json['y']);
    final width = _asFiniteDouble(json['width']);
    final height = _asFiniteDouble(json['height']);
    if (x == null || y == null || width == null || height == null) return null;
    final bounds = Rect.fromLTWH(x, y, width, height);
    return isValid(bounds) ? bounds : null;
  }

  /// Whether [bounds] can be safely passed to the native window API.
  static bool isValid(Rect bounds) =>
      bounds.left.isFinite &&
      bounds.top.isFinite &&
      bounds.width.isFinite &&
      bounds.height.isFinite &&
      bounds.width > 0 &&
      bounds.height > 0;

  Future<String> _filePath() async =>
      p.join((await _getDirectory()).path, fileName);

  static double? _asFiniteDouble(Object? value) {
    if (value is! num || !value.isFinite) return null;
    return value.toDouble();
  }
}
