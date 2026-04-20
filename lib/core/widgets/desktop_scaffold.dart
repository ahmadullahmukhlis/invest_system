import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/responsive.dart';
import '../data/sync_providers.dart';
import '../utils/permission_utils.dart';
import '../../data/user_providers.dart';
import 'app_drawer.dart';
import 'app_sidebar.dart';

class DesktopScaffold extends ConsumerWidget {
  const DesktopScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.padding,
    this.showRefreshAction = true,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final EdgeInsets? padding;
  final bool showRefreshAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isDesktop(context);
    final contentPadding = padding ?? const EdgeInsets.all(20);
    final userRepo = ref.watch(userRepositoryProvider);
    final canUseSync = canView(userRepo, 'sync');
    final desktopActions = [
      if (showRefreshAction && canUseSync)
        IconButton(
          tooltip: 'Sync',
          icon: const Icon(Icons.sync),
          onPressed: () async {
            await ref.read(syncServiceProvider).syncAll();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sync completed.')));
            }
          },
        ),
      ...actions,
    ];

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        drawer: const AppDrawer(),
        floatingActionButton: floatingActionButton,
        body: Padding(padding: const EdgeInsets.all(16), child: body),
      );
    }

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Row(
          children: [
            const AppSidebar(),
            Expanded(
              child: Column(
                children: [
                  _DesktopTopBar(title: title, actions: desktopActions),
                  Expanded(
                    child: Padding(padding: contentPadding, child: body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
