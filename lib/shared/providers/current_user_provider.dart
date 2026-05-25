import 'package:cenko/features/auth/data/user_model.dart';
import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/internet_status_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = FutureProvider.autoDispose<UserModel?>((ref) {
  ref.watch(internetStatusProvider);
  final authState = ref.watch(authStateProvider);
  final session = authState.asData?.value;
  if (session == null) return Future.value(null);
  return ref.read(userRepositoryProvider).getUser(session.user.id);
});
