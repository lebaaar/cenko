import 'dart:async';

import 'package:cenko/core/constants/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _PlanCacheEntry {
  const _PlanCacheEntry({required this.isFreePlan, required this.expiresAt});

  final bool isFreePlan;
  final DateTime expiresAt;
}

const Duration _defaultPlanCacheTtl = Duration(minutes: 5);
final Map<String, _PlanCacheEntry> _planCacheByUid = <String, _PlanCacheEntry>{};
final Map<String, Future<bool>> _inFlightPlanChecksByUid = <String, Future<bool>>{};

Future<bool> isFreePlan(FirebaseFirestore firestore, String uid, {Duration cacheTtl = _defaultPlanCacheTtl}) async {
  final now = DateTime.now();
  final cachedEntry = _planCacheByUid[uid];
  if (cachedEntry != null && cachedEntry.expiresAt.isAfter(now)) {
    return cachedEntry.isFreePlan;
  }

  final inFlight = _inFlightPlanChecksByUid[uid];
  if (inFlight != null) {
    return inFlight;
  }

  final request = firestore
      .collection('users')
      .doc(uid)
      .get()
      .then((doc) {
        final freePlan = (doc.data()?['plan'] as String? ?? kFreePlanPlan) == kFreePlanPlan;
        _planCacheByUid[uid] = _PlanCacheEntry(isFreePlan: freePlan, expiresAt: now.add(cacheTtl));
        return freePlan;
      })
      .whenComplete(() {
        _inFlightPlanChecksByUid.remove(uid);
      });

  _inFlightPlanChecksByUid[uid] = request;
  return request;
}

void clearPlanCacheForUser(String uid) {
  _planCacheByUid.remove(uid);
  _inFlightPlanChecksByUid.remove(uid);
}

void clearPlanCache() {
  _planCacheByUid.clear();
  _inFlightPlanChecksByUid.clear();
}
