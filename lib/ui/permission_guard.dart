import 'package:flutter/material.dart';

import '../data/permissions.dart';
import '../data/user_profile.dart';

class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    super.key,
    required this.profile,
    required this.module,
    required this.builder,
    this.emptyMessage = 'You do not have access to this page.',
  });

  final UserProfile? profile;
  final String module;
  final WidgetBuilder builder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final allowed = _canView();
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: Center(child: Text(emptyMessage)),
      );
    }
    return builder(context);
  }

  bool _canView() {
    final profile = this.profile;
    if (profile == null) return false;
    final perms = profile.permissions[module] ??
        PermissionSet(view: false, create: false, edit: false, remove: false);
    return perms.view;
  }
}
