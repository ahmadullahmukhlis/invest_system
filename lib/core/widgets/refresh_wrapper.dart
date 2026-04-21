import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync_providers.dart';

class RefreshWrapper extends ConsumerWidget {
  const RefreshWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        debugPrint('[Refresh] User triggered pull-to-refresh.');
        try {
          await ref.read(syncServiceProvider).syncAll();
          debugPrint('[Refresh] Sync completed successfully.');
        } catch (error, stackTrace) {
          debugPrint('[Refresh] Sync failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          rethrow;
        }
      },
      child: child,
    );
  }
}
