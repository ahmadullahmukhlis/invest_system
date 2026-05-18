import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/user_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final profile = userRepo.current;

    return DesktopScaffold(
      title: 'Settings',
      showRefreshAction: false,
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            const SectionHeader(
              title: 'Offline Database',
              subtitle: 'This Windows app now runs fully on local SQLite',
              icon: Icons.storage_outlined,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local-only mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Firebase Realtime Database sync and cloud sign-in have been removed from the active Windows app. All business data is stored in the local SQLite database on this device.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'Current Profile',
              subtitle: 'Local desktop session information',
              icon: Icons.person_outline,
            ),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.computer)),
                title: Text(profile?.name ?? 'Local Administrator'),
                subtitle: Text(profile?.email ?? 'offline@local'),
                trailing: Text(profile?.role.replaceAll('_', ' ') ?? 'offline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
