import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Platform-agnostic image widget that works on both mobile and web
class PlatformImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, use Image.memory with bytes or Image.network if it's a URL
      if (imageBytes != null) {
        return Image.memory(
          imageBytes!,
          fit: fit,
          width: width,
          height: height,
        );
      } else if (imagePath.startsWith('http://') || 
                 imagePath.startsWith('https://') ||
                 imagePath.startsWith('data:image')) {
        // If it's a URL or data URI, use Image.network
        return Image.network(
          imagePath,
          fit: fit,
          width: width,
          height: height,
          headers: headers,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 4),
                    Text(
                      'Image not available',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        // For web file paths from image_picker, show placeholder
        // In production, you should store bytes when picking images
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
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          fit: fit,
          width: width,
          height: height,
          headers: headers,
          errorBuilder: (context, error, stackTrace) {
             return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 4),
                    Text(
                      'Image not available',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        return Image.file(
          File(imagePath),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 4),
                    Text(
                      'Image not available',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    }
  }
}

