import 'package:cenko/features/auth/data/user_model.dart';
import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'internet_status_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  ref.watch(internetStatusProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value(null);

  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});
