import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int totalSpent;
  final int receiptsScanned;
  final List<Statistics> mostVisitedStores;

  const UserStats({this.totalSpent = 0, this.receiptsScanned = 0, this.mostVisitedStores = const []});

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
    totalSpent: m['total_spent'] as int? ?? 0,
    receiptsScanned: m['receipts_scanned'] as int? ?? 0,
    mostVisitedStores: (m['most_visited_stores'] as List<dynamic>? ?? []).map((e) => Statistics.fromMap(e as Map<String, dynamic>)).toList(),
  );

  Map<String, dynamic> toMap() => {
    'total_spent': totalSpent,
    'receipts_scanned': receiptsScanned,
    'most_visited_stores': mostVisitedStores.map((s) => s.toMap()).toList(),
  };
}

class UserSettings {
  final String theme;
  final bool notificationsEnabled;
  final String language;

  const UserSettings({this.theme = 'system', this.notificationsEnabled = true, this.language = 'en'});

  static String normalizeTheme(String? theme) {
    switch (theme) {
      case 'light':
      case 'dark':
      case 'system':
        return theme!;
      default:
        return 'system';
    }
  }

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
    theme: normalizeTheme(m['theme'] as String?),
    notificationsEnabled: m['notificationsEnabled'] as bool? ?? true,
    language: m['language'] as String? ?? 'en',
  );

  Map<String, dynamic> toMap() => {'theme': theme, 'notificationsEnabled': notificationsEnabled, 'language': language};
}

class UserModel {
  final String userId;
  final String name;
  final String email;
  final DateTime createdAt;
  final String authProvider;
  final String? googleId;
  final UserSettings settings;
  final UserStats stats;

  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.createdAt,
    required this.authProvider,
    this.googleId,
    this.settings = const UserSettings(),
    this.stats = const UserStats(),
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: m['user_id'] as String,
      name: m['name'] as String,
      email: m['email'] as String,
      createdAt: (m['created_at'] as Timestamp).toDate(),
      authProvider: m['auth_provider'] as String,
      googleId: m['google_id'] as String?,
      settings: UserSettings.fromMap(m['settings'] as Map<String, dynamic>),
      stats: UserStats.fromMap(m['stats'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'name': name,
    'email': email,
    'created_at': Timestamp.fromDate(createdAt),
    'auth_provider': authProvider,
    'google_id': googleId,
    'settings': settings.toMap(),
    'stats': stats.toMap(),
  };
}

class Statistics {
  final String storeName;
  final String logoUrl;
  final int visitCount;

  const Statistics({required this.storeName, required this.logoUrl, required this.visitCount});

  factory Statistics.fromMap(Map<String, dynamic> m) => Statistics(
    storeName: m['store_name'] as String? ?? 'Unknown store',
    logoUrl: m['logo_url'] as String? ?? '',
    visitCount: m['visit_count'] as int? ?? 0,
  );

  Map<String, dynamic> toMap() => {'store_name': storeName, 'logo_url': logoUrl, 'visit_count': visitCount};
}
