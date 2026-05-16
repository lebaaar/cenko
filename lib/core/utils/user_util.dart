import 'package:cenko/core/constants/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> isFreePlan(FirebaseFirestore firestore, String uid) async {
  final doc = await firestore.collection('users').doc(uid).get();
  return (doc.data()?['plan'] as String? ?? kFreePlanPlan) == kFreePlanPlan;
}
