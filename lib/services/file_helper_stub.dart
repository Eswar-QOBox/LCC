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
}
