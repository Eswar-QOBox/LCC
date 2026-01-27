import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Aspect ratio used for Aadhaar grid: normal card w/h ≈ 1.58, vertical h/w ≈ 1.58.
const double _gridAspect = 1.58;

/// Center-crops the image at [imagePath] to the grid aspect (normal or vertical card).
/// Returns the path to a new temp JPEG, or null on failure.
/// Used only on mobile (dart.library.io) via conditional import.
Future<String?> cropToGridAspect(String imagePath, bool isVertical) async {
  try {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final w = image.width;
    final h = image.height;
    int cropW;
    int cropH;
    if (isVertical) {
      // Vertical card: height/width = 1.58
      cropW = (w < h / _gridAspect) ? w : (h / _gridAspect).round();
      cropH = (cropW * _gridAspect).round().clamp(1, h);
      cropW = (cropH / _gridAspect).round().clamp(1, w);
    } else {
      // Normal card: width/height = 1.58
      cropH = (h < w / _gridAspect) ? h : (w / _gridAspect).round();
      cropW = (cropH * _gridAspect).round().clamp(1, w);
      cropH = (cropW / _gridAspect).round().clamp(1, h);
    }
    if (cropW <= 0 || cropH <= 0) return null;

    final x = ((w - cropW) / 2).round().clamp(0, w - 1);
    final y = ((h - cropH) / 2).round().clamp(0, h - 1);
    final cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: cropW,
      height: cropH,
    );
    final jpeg = img.encodeJpg(cropped, quality: 92);

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/aadhaar_grid_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(jpeg);
    return outPath;
  } catch (_) {
    return null;
  }
}
