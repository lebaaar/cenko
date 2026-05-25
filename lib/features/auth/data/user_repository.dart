import 'package:cenko/features/auth/data/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final _client = Supabase.instance.client;

  Future<UserModel?> getUser(String id) async {
    final data = await _client.from('user').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  Future<void> updateDisplayName(String id, String name) async {
    await _client.from('user').update({'display_name': name.trim()}).eq('id', id);
  }

  Future<void> updateEmail(String id, String email) async {
    await _client.from('user').update({'email': email.trim()}).eq('id', id);
  }

  Future<void> updateSettings(String id, {String? theme, String? lang, bool? notificationsEnabled}) async {
    final updates = <String, dynamic>{};
    if (theme != null) updates['theme'] = theme;
    if (lang != null) updates['lang'] = lang;
    if (notificationsEnabled != null) updates['notifications_enabled'] = notificationsEnabled;
    if (updates.isEmpty) return;
    await _client.from('user').update(updates).eq('id', id);
  }
}
