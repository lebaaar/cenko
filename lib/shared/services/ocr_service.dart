import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for on-device optical character recognition (OCR) using ML Kit.
class OcrService {
  late final TextRecognizer _textRecognizer;

  OcrService() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Extracts raw text from an image file using on-device text recognition.
  ///
  /// Returns the extracted text or null if recognition fails.
  Future<String?> extractTextFromFile(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      return await _extractTextFromInputImage(inputImage);
    } catch (e) {
      return null;
    }
  }

  /// Internal helper to extract text from an InputImage.
  Future<String?> _extractTextFromInputImage(InputImage inputImage) async {
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text;
      if (extractedText.isEmpty) {
        return null;
      }

      return extractedText;
    } catch (e) {
      return null;
    }
  }

  /// Disposes the text recognizer and releases resources.
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
