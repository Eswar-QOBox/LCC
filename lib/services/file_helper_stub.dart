// Stub file for web platform
// This file provides a stub File class when dart:io is not available
import 'dart:typed_data';

/// Stub File class for web platform
class File {
  final String path;
  
  File(this.path);
  
  Future<bool> exists() async {
    throw UnsupportedError('File operations not available on web');
  }
  
  Future<Uint8List> readAsBytes() async {
    throw UnsupportedError('File operations not available on web');
  }
  
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write}) async {
    throw UnsupportedError('File operations not available on web');
  }
  
  Future<void> delete({bool recursive = false}) async {
    throw UnsupportedError('File operations not available on web');
  }
}

/// Stub Directory class for web platform
class Directory {
  final String path;
  
  Directory(this.path);
  
  Future<bool> exists() async {
    throw UnsupportedError('Directory operations not available on web');
  }
  
  Future<Directory> createTemp(String prefix) async {
    throw UnsupportedError('Directory operations not available on web');
  }
  
  Future<void> delete({bool recursive = false}) async {
    throw UnsupportedError('Directory operations not available on web');
  }
  
  static Future<Directory> systemTemp() async {
    throw UnsupportedError('Directory operations not available on web');
  }
}

/// Stub FileMode enum for web platform
enum FileMode {
  read,
  write,
  append,
  writeOnly,
  writeOnlyAppend,
}
