import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum ContactType {
  contact('Contact', 0x3498DB, 'DISCORD_WEBHOOK_CONTACT'),
  feedback('Feedback', 0x2ECC71, 'DISCORD_WEBHOOK_FEEDBACK'),
  featureRequest('Feature Request', 0xF39C12, 'DISCORD_WEBHOOK_FEATURE_REQUEST'),
  bugReport('Bug Report', 0xE74C3C, 'DISCORD_WEBHOOK_BUG_REPORT');

  const ContactType(this.label, this.color, this._envKey);

  final String label;
  final int color;
  final String _envKey;

  String get webhookUrl => dotenv.get(_envKey);
}

class DiscordWebhookService {
  DiscordWebhookService._();

  static Future<void> send({
    required ContactType type,
    required String message,
    String? name,
    required String email,
    String? userId,
    Map<String, String>? bugInfo,
  }) async {
    final payload = {
      'username': 'Cenko App',
      'embeds': [
        {
          'title': type.label,
          'color': type.color,
          'fields': [
            if (name != null && name.isNotEmpty) {'name': 'Name', 'value': name, 'inline': true},
            {'name': 'Email', 'value': email, 'inline': true},
            if (userId != null) {'name': 'User ID', 'value': userId, 'inline': false},
            {'name': 'Message', 'value': message, 'inline': false},
            if (bugInfo != null)
              for (final entry in bugInfo.entries)
                {'name': entry.key, 'value': entry.value, 'inline': true},
          ],
        },
      ],
    };

    final response = await http.post(
      Uri.parse(type.webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send message (${response.statusCode})');
    }
  }
}
