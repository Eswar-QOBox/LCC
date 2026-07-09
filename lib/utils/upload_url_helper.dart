import 'api_config.dart';

/// Resolves relative upload paths from the JHipster backend to full authenticated URLs.
///
/// Backend returns paths like `/api/uploads/lead-documents/{file}`.
/// Legacy Flask paths (`/api/v1/uploads/...`, `/uploads/...`) are normalized.
class UploadUrlHelper {
  static String resolve(String raw) {
    if (raw.isEmpty) return raw;
    if (_isAbsoluteOrLocal(raw)) return raw;

    var path = raw;

    if (path.startsWith('baseUrl')) {
      path = path.replaceFirst('baseUrl', ApiConfig.baseUrl);
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
    }

    if (path.startsWith('http://localhost:5000')) {
      return path.replaceFirst('http://localhost:5000', ApiConfig.baseUrl);
    }

    if (path.startsWith('uploads/') || path.startsWith('api/')) {
      path = '/$path';
    }

    path = _normalizeApiPath(path);

    if (path.startsWith('/api/')) {
      return '${ApiConfig.baseUrl}$path';
    }

    return raw;
  }

  static String _normalizeApiPath(String path) {
    if (path.startsWith('/api/v1/uploads/files/')) {
      return path.replaceFirst('/api/v1/uploads/files/', '/api/uploads/');
    }
    if (path.startsWith('/api/v1/uploads/')) {
      return path.replaceFirst('/api/v1/uploads/', '/api/uploads/');
    }
    if (path.startsWith('/uploads/')) {
      return '/api$path';
    }
    return path;
  }

  static bool _isAbsoluteOrLocal(String raw) {
    return raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('blob:') ||
        raw.startsWith('data:');
  }

  static bool isNetworkPath(String raw) {
    if (raw.isEmpty) return false;
    return _isAbsoluteOrLocal(raw) ||
        raw.startsWith('/uploads/') ||
        raw.startsWith('/api/') ||
        raw.startsWith('uploads/') ||
        raw.startsWith('api/') ||
        raw.startsWith('baseUrl') ||
        raw.startsWith('http://localhost:5000');
  }
}
