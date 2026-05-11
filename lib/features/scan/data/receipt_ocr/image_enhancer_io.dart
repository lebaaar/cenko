import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<String> enhancedPathForOcr(String filePath, Uint8List bytes) async {
  try {
    final enhanced = await compute(_doEnhance, bytes);
    final enhancedPath = '${filePath}_ocr.jpg';
    await File(enhancedPath).writeAsBytes(enhanced);
    return enhancedPath;
  } catch (_) {
    return filePath;
  }
}

Uint8List _doEnhance(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final gray = img.grayscale(decoded);
    final adjusted = img.adjustColor(gray, contrast: 1.45, brightness: 1.08);
    return img.encodeJpg(adjusted, quality: 92);
  } catch (_) {
    return bytes;
  }
}
