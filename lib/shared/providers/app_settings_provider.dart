import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// App-wide settings (feature flags / kill switches) from the `app_settings` table.
/// Fetched once when the app is opened and kept in memory; re-fetched on reconnect.
final appSettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  ref.watch(internetStatusProvider);
  final rows = await Supabase.instance.client.from('app_settings').select('setting, value');
  return {for (final row in rows) row['setting'] as String: row['value'].toString()};
});

/// Kill switch for all receipt scanning functionality.
/// Fails open: defaults to true while loading or when the settings fetch fails,
/// and only disables when the `receipt_scanning_enabled` setting is explicitly 'false'.
final receiptScanningEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsProvider).asData?.value;
  return settings?['receipt_scanning_enabled']?.trim().toLowerCase() != 'false';
});
