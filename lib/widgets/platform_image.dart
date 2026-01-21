import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Platform-agnostic image widget that works on both mobile and web
class PlatformImage extends StatefulWidget {
  final String imagePath;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Uint8List? imageBytes;
  final Map<String, String>? headers;

  const PlatformImage({
    super.key,
    required this.imagePath,
    this.fit,
    this.width,
    this.height,
    this.imageBytes,
    this.headers,
  });

  @override
  State<PlatformImage> createState() => _PlatformImageState();
}

class _PlatformImageState extends State<PlatformImage> {
  Uint8List? _webFetchedBytes;
  bool _isLoadingWeb = false;
  bool _hasWebError = false;

  @override
  void initState() {
    super.initState();
    _fetchWebImageIfNeeded();
  }

  @override
  void didUpdateWidget(PlatformImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath || 
        oldWidget.headers != widget.headers ||
        oldWidget.imageBytes != widget.imageBytes) {
      _fetchWebImageIfNeeded();
    }
  }

  /// Validates if bytes contain actual image data by checking file headers
  bool _isValidImageData(Uint8List bytes) {
    if (bytes.length < 4) return false;
    
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
    
    // WebP: 52 49 46 46 ... 57 45 42 50
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    
    return false;
  }


  Future<void> _fetchWebImageIfNeeded() async {
    // Only fetch manually if:
    // 1. We are on Web
    // 2. We don't have explicit bytes passed
    // 3. It's an HTTP URL (not data uri, not blob)
    // 4. We have headers (Authorization) that Image.network ignores on Web
    if (kIsWeb && 
        widget.imageBytes == null && 
        (widget.imagePath.startsWith('http://') || widget.imagePath.startsWith('https://')) && 
        widget.headers != null) {
      
      setState(() {
        _isLoadingWeb = true;
        _hasWebError = false;
        _webFetchedBytes = null;
      });

      try {
        final response = await http.get(
          Uri.parse(widget.imagePath), 
          headers: widget.headers
        );
        
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          
          // Validate that we received actual image data, not HTML or other content
          if (_isValidImageData(bytes)) {
            if (mounted) {
              setState(() {
                _webFetchedBytes = response.bodyBytes;
                _isLoadingWeb = false;
              });
            }
          } else {
            debugPrint('PlatformImage: Invalid image data received from ${widget.imagePath}');
            debugPrint('PlatformImage: Content-Type: ${response.headers['content-type']}');
            
            // Log first few bytes to help diagnose the issue
            if (bytes.length >= 10) {
              final header = bytes.sublist(0, 10).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
              debugPrint('PlatformImage: Response header: $header');
              
              // Check if it's HTML
              if (bytes[0] == 0x3c && (bytes[1] == 0x21 || bytes[1] == 0x68)) {
                final htmlSnippet = String.fromCharCodes(bytes.sublist(0, bytes.length > 100 ? 100 : bytes.length));
                debugPrint('PlatformImage: Server returned HTML: $htmlSnippet');
              }
            }
            
            if (mounted) {
              setState(() {
                _hasWebError = true;
                _isLoadingWeb = false;
              });
            }
          }
        } else {
          debugPrint('PlatformImage: Failed to load image ${widget.imagePath}: ${response.statusCode}');
          if (mounted) {
            setState(() {
              _hasWebError = true;
              _isLoadingWeb = false;
            });
          }
        }
      } catch (e) {
        debugPrint('PlatformImage: Error loading image: $e');
        if (mounted) {
          setState(() {
            _hasWebError = true;
            _isLoadingWeb = false;
          });
        }
      }
    } else {
      // If condition no longer met, clear fetched state
      if (_webFetchedBytes != null || _isLoadingWeb || _hasWebError) {
        setState(() {
          _webFetchedBytes = null;
          _isLoadingWeb = false;
          _hasWebError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // 1. Use explicitly passed bytes if available
      if (widget.imageBytes != null) {
        return Image.memory(
          widget.imageBytes!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        );
      }
      
      // 2. If fetching authenticated image on web
      if (_isLoadingWeb) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      
      if (_hasWebError) {
        return _buildErrorWidget();
      }

      if (_webFetchedBytes != null) {
        return Image.memory(
          _webFetchedBytes!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        );
      }

      // 3. Standard Web Handling (no headers or public url)
      if (widget.imagePath.startsWith('http://') || 
          widget.imagePath.startsWith('https://') ||
          widget.imagePath.startsWith('data:image')) {
        return Image.network(
          widget.imagePath,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          // Note: headers are ignored on Web by Image.network
          // That's why we have _fetchWebImageIfNeeded above
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } else {
        // For web file paths from image_picker, show placeholder
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Image preview not available on web'),
            ],
          ),
        );
      }
    } else {
      // On mobile/desktop
      if (widget.imagePath.startsWith('http://') || widget.imagePath.startsWith('https://')) {
        return Image.network(
          widget.imagePath,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          headers: widget.headers,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } else {
        return Image.file(
          File(widget.imagePath),
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      }
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Image not available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Check console for details',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

