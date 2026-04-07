import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'app_nav.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navIndexProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.indigo,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Bulk Sales & Accounting',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final selected = index == selectedIndex;
                return ListTile(
                  leading: Icon(item.icon, color: selected ? AppColors.accent : null),
                  title: Text(item.label),
                  selected: selected,
                  onTap: () {
                    ref.read(navIndexProvider.notifier).state = index;
                    Navigator.of(context).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
