import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

final internetStatusProvider = StreamProvider<InternetStatus>((ref) {
  final internetConnection = InternetConnection.createInstance(
    triggerStream: Connectivity().onConnectivityChanged,
    checkInterval: const Duration(milliseconds: 7500),
  );

  return internetConnection.onStatusChange;
});
