import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import for file operations - only on non-web platforms
import 'dart:io' if (dart.library.html) '../services/file_helper_stub.dart' as io;

/// Copies a local file into a stable temp folder and returns that new path.
///
/// This helps avoid issues where camera/gallery paths become invalid later.
/// On web, or for remote/blob paths, it returns the original path.
Future<String> persistLocalPathIfNeeded(
  String path, {
  String? preferredExtension,
  String subdir = 'lcc_uploads',
  String prefix = 'upload',
}) async {
  if (kIsWeb) return path;

  // Keep remote/blob paths as-is.
  if (path.startsWith('http') ||
      path.startsWith('/uploads/') ||
      path.startsWith('/api/') ||
      path.startsWith('blob:')) {
    return path;
  }

  try {
    final dir = io.Directory('${io.Directory.systemTemp.path}/$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final lastSlash = path.lastIndexOf('/');
    final basename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
    final dot = basename.lastIndexOf('.');
    final ext = (preferredExtension != null && preferredExtension.isNotEmpty)
        ? preferredExtension
        : (dot >= 0 ? basename.substring(dot + 1) : 'jpg');

    final uniqueName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final targetPath = '${dir.path}/$uniqueName';
    final copied = await io.File(path).copy(targetPath);
    return copied.path;
  } catch (_) {
    return path;
  }
}

