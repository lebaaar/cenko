class UserModel {
  final String id;
  final int planId;
  final String displayName;
  final String email;
  final DateTime joinedAt;
  final String authProvider;
  final String? googleId;
  final String theme;
  final String lang;
  final bool notificationsEnabled;

  const UserModel({
    required this.id,
    required this.planId,
    required this.displayName,
    required this.email,
    required this.joinedAt,
    required this.authProvider,
    this.googleId,
    this.theme = 'system',
    this.lang = 'en',
    this.notificationsEnabled = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    id: m['id'] as String,
    planId: m['plan_id'] as int,
    displayName: m['display_name'] as String,
    email: m['email'] as String,
    joinedAt: DateTime.parse(m['joined_at'] as String),
    authProvider: m['auth_provider'] as String,
    googleId: m['google_id'] as String?,
    theme: _normalizeTheme(m['theme'] as String?),
    lang: m['lang'] as String? ?? 'en',
    notificationsEnabled: m['notifications_enabled'] as bool? ?? true,
  );

  static String _normalizeTheme(String? theme) {
    switch (theme) {
      case 'light':
      case 'dark':
      case 'system':
        return theme!;
      default:
        return 'system';
    }
  }

  bool get isFreePlan => planId == 1;
}
