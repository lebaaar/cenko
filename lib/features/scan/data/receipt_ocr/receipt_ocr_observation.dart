import 'dart:ui';

class ReceiptOcrObservation {
  ReceiptOcrObservation({required this.text, required this.imageSize, required this.boundingBox});

  final String text;
  final Size imageSize;
  final Rect? boundingBox;
}
