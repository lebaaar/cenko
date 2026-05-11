import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ReceiptAiService {
  const ReceiptAiService();

  static const MethodChannel _channel = MethodChannel('cenko/receipt_ai');

  Future<String> extractReceiptJsonFromOcr(String prompt) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('On-device receipt AI is only available on Android');
    }

    final result = await _channel.invokeMethod<String>('extractReceiptJsonFromOcr', <String, dynamic>{'prompt': prompt});

    final text = result?.trim() ?? '';
    if (text.isEmpty) {
      throw StateError('Gemini Nano returned an empty response');
    }

    return text;
  }
}
