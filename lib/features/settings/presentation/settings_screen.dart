import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/sync_providers.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../data/permissions.dart';
import '../../../data/user_providers.dart';
import '../../../data/user_profile.dart';
import '../../../data/user_repository.dart';
import '../../../ui/responsive.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _roles = ['viewer', 'staff', 'admin', 'super_admin'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userRepositoryProvider).startAllUsersListener();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRepo = ref.watch(userRepositoryProvider);
    final isDesktop = Responsive.isDesktop(context);
    final currentRole = userRepo.currentRole;
    final canManageUsers =
        currentRole == 'admin' || currentRole == 'super_admin';
    final canAssignSuper = currentRole == 'super_admin';
    final canSync = currentRole == 'super_admin' ||
        (userRepo.current?.permissions['sync']?.view ?? false);

    return DesktopScaffold(
      title: 'Settings',
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            const SectionHeader(
              title: 'Data Sync',
              subtitle: 'Keep local and cloud data in sync',
              icon: Icons.sync,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Sync',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Sync local SQLite and Firebase Realtime Database.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: !canSync
                              ? null
                              : () async {
                                  await ref.read(syncServiceProvider).syncAll();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sync completed.'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Now'),
                        ),
                        OutlinedButton.icon(
                          onPressed: !canSync
                              ? null
                              : () async {
                                  await ref.read(syncServiceProvider).pushAll();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Pushed local data to server.'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('SQLite → Realtime'),
                        ),
                        OutlinedButton.icon(
                          onPressed: !canSync
                              ? null
                              : () async {
                                  await ref.read(syncServiceProvider).pullAll();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Pulled server data to SQLite.'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('Realtime → SQLite'),
                        ),
                      ],
                    ),
                    if (!canSync)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Sync access is disabled for your account.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isDesktop) ...[
              const SectionHeader(
                title: 'Users & Roles',
                subtitle: 'Assign roles and permissions',
                icon: Icons.manage_accounts_outlined,
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<List<UserProfile>>(
                    stream: userRepo.allUsersStream,
                    builder: (context, snapshot) {
                      final users = snapshot.data ?? const [];
                      if (!canManageUsers) {
                        return const Text(
                          'You do not have permission to manage users.',
                        );
                      }
                      if (users.isEmpty) {
                        return const Text('No users found.');
                      }
                      return DesktopTable(
                        minWidth: 1000,
                        columns: const [
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Active')),
                          DataColumn(label: Text('Sync')),
                          DataColumn(label: Text('Permissions')),
                        ],
                        rows: [
                          for (final user in users)
                            _buildUserRow(
                              context,
                              userRepo,
                              user,
                              canAssignSuper: canAssignSuper,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'Account',
              subtitle: 'Security and session',
              icon: Icons.person_outline,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildUserRow(
    BuildContext context,
    UserRepository userRepo,
    UserProfile user, {
    required bool canAssignSuper,
  }) {
    final roleValue = _roles.contains(user.role) ? user.role : 'viewer';
    final canEditRole =
        userRepo.currentRole == 'super_admin' || userRepo.currentRole == 'admin';
    final canEditSuper = canAssignSuper || user.role != 'super_admin';
    final canToggleSync = canEditRole && canEditSuper;

    return DataRow(
      cells: [
        DataCell(Text(user.name.isEmpty ? 'Unnamed' : user.name)),
        DataCell(Text(user.email)),
        DataCell(
          DropdownButton<String>(
            value: roleValue,
            items: _roles
                .where((role) => canAssignSuper || role != 'super_admin')
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: !canEditRole || !canEditSuper
                ? null
                : (value) async {
                    if (value == null) return;
                    await userRepo.updateUserRole(user.uid, value);
                  },
          ),
        ),
        DataCell(
          Switch(
            value: user.isActive,
            onChanged: !canEditRole || !canEditSuper
                ? null
                : (value) async {
                    await userRepo.updateUserActive(user.uid, value);
                  },
          ),
        ),
        DataCell(
          Switch(
            value: user.permissions['sync']?.view ?? false,
            onChanged: !canToggleSync
                ? null
                : (value) async {
                    final updated =
                        Map<String, PermissionSet>.from(user.permissions);
                    final current =
                        updated['sync'] ?? PermissionSet(view: false, create: false, edit: false, remove: false);
                    updated['sync'] = current.copyWith(view: value);
                    await userRepo.updateUserPermissions(user.uid, updated);
                  },
          ),
        ),
        DataCell(
          OutlinedButton(
            onPressed: !canEditRole || !canEditSuper
                ? null
                : () => _editPermissions(context, userRepo, user),
            child: const Text('Edit'),
          ),
        ),
      ],
    );
  }

  Future<void> _editPermissions(
    BuildContext context,
    UserRepository userRepo,
    UserProfile user,
  ) async {
    final permissions = Map<String, PermissionSet>.from(
      normalizePermissions(user.role, user.permissions),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Permissions • ${user.name.isEmpty ? user.email : user.name}',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final module in modules) ...[
                      _PermissionRow(
                        module: module,
                        permission: permissions[module]!,
                        onChanged: (value) {
                          permissions[module] = value;
                        },
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await userRepo.updateUserPermissions(user.uid, permissions);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _PermissionRow extends StatefulWidget {
  const _PermissionRow({
    required this.module,
    required this.permission,
    required this.onChanged,
  });

  final String module;
  final PermissionSet permission;
  final ValueChanged<PermissionSet> onChanged;

  @override
  State<_PermissionRow> createState() => _PermissionRowState();
}

class _PermissionRowState extends State<_PermissionRow> {
  late PermissionSet _permission;

  @override
  void initState() {
    super.initState();
    _permission = widget.permission;
  }

  void _update(PermissionSet next) {
    setState(() => _permission = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.module.replaceAll('_', ' ').toUpperCase()),
        ),
        _permSwitch('V', _permission.view, (value) {
          _update(_permission.copyWith(view: value));
        }),
        _permSwitch('C', _permission.create, (value) {
          _update(_permission.copyWith(create: value));
        }),
        _permSwitch('E', _permission.edit, (value) {
          _update(_permission.copyWith(edit: value));
        }),
        _permSwitch('D', _permission.remove, (value) {
          _update(_permission.copyWith(remove: value));
        }),
      ],
    );
  }

  Widget _permSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
