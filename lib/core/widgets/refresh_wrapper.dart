import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync_providers.dart';

class RefreshWrapper extends ConsumerWidget {
  const RefreshWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(syncServiceProvider).syncAll(),
      child: child,
    );
  }
}
