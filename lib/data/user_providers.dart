import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_repository.dart';
import 'user_profile.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  throw UnimplementedError();
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(userRepositoryProvider).currentUserStream;
});
