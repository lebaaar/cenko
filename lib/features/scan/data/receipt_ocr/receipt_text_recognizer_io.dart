import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_ocr_observation.dart';

class ReceiptTextRecognizer {
  ReceiptTextRecognizer() : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _textRecognizer;

  Future<ReceiptOcrObservation> analyzeFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return ReceiptOcrObservation(
      text: recognizedText.text,
      imageSize: _sizeFromInputImage(inputImage),
      boundingBox: _unionTextBounds(recognizedText),
    );
  }

  Future<ReceiptOcrObservation> analyzeCameraImage(CameraImage image, {required int rotationDegrees}) async {
    final inputImage = InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: _rotatedSize(image, rotationDegrees),
        rotation: _rotationFromDegrees(rotationDegrees),
        format: _inputImageFormatFromCamera(image.format.raw),
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );

    final recognizedText = await _textRecognizer.processImage(inputImage);
    return ReceiptOcrObservation(
      text: recognizedText.text,
      imageSize: _sizeFromInputImage(inputImage),
      boundingBox: _unionTextBounds(recognizedText),
    );
  }

  Future<String> extractText(String imagePath) async {
    final observation = await analyzeFile(imagePath);
    return observation.text;
  }

  void close() {
    _textRecognizer.close();
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final bytesBuilder = BytesBuilder();
    for (final plane in planes) {
      bytesBuilder.add(plane.bytes);
    }
    return bytesBuilder.toBytes();
  }

  InputImageRotation _rotationFromDegrees(int rotationDegrees) {
    switch (rotationDegrees % 360) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _inputImageFormatFromCamera(int rawFormat) {
    return InputImageFormatValue.fromRawValue(rawFormat) ?? InputImageFormat.nv21;
  }

  Size _rotatedSize(CameraImage image, int rotationDegrees) {
    if (rotationDegrees % 180 == 0) {
      return Size(image.width.toDouble(), image.height.toDouble());
    }
    return Size(image.height.toDouble(), image.width.toDouble());
  }

  Size _sizeFromInputImage(InputImage inputImage) {
    return inputImage.metadata?.size ?? const Size(1, 1);
  }

  Rect? _unionTextBounds(RecognizedText recognizedText) {
    final rects = <Rect>[];
    for (final block in recognizedText.blocks) {
      rects.add(block.boundingBox);
      rects.addAll(block.lines.map((line) => line.boundingBox));
    }

    if (rects.isEmpty) {
      return null;
    }

    var left = rects.first.left;
    var top = rects.first.top;
    var right = rects.first.right;
    var bottom = rects.first.bottom;

    for (final rect in rects.skip(1)) {
      if (rect.left < left) left = rect.left;
      if (rect.top < top) top = rect.top;
      if (rect.right > right) right = rect.right;
      if (rect.bottom > bottom) bottom = rect.bottom;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
}

ReceiptTextRecognizer createReceiptTextRecognizer() => ReceiptTextRecognizer();
