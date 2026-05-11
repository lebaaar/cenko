import 'receipt_ocr_observation.dart';

class ReceiptTextRecognizer {
  Future<String> extractText(String imagePath) async {
    throw UnsupportedError('OCR is only supported on mobile platforms');
  }

  Future<ReceiptOcrObservation> analyzeFile(String imagePath) async {
    throw UnsupportedError('OCR is only supported on mobile platforms');
  }

  Future<ReceiptOcrObservation> analyzeCameraImage(dynamic image, {required int rotationDegrees}) async {
    throw UnsupportedError('OCR is only supported on mobile platforms');
  }

  void close() {}
}

ReceiptTextRecognizer createReceiptTextRecognizer() => ReceiptTextRecognizer();
