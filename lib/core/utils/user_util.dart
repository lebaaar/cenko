import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns true if the user with [uid] is on the Free plan (plan_id = 1).
Future<bool> isFreePlan(String uid) async {
  final row = await Supabase.instance.client
      .from('user')
      .select('plan_id')
      .eq('id', uid)
      .maybeSingle();
  return (row?['plan_id'] as int?) == 1;
}

/// No-op — kept for call-site compatibility.
void clearPlanCacheForUser(String uid) {}

/// No-op — kept for call-site compatibility.
void clearPlanCache() {}
