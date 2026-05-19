import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/sync_providers.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
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

    return DesktopScaffold(
      title: 'Settings',
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            const SectionHeader(
              title: 'Local Data',
              subtitle: 'SQLite only on Windows',
              icon: Icons.storage_outlined,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Data',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This Windows build stores data locally in SQLite. Firebase and cloud sync are disabled.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await ref.read(syncServiceProvider).syncAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Local data refreshed.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync),
                          label: const Text('Refresh'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(syncServiceProvider).pushAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('SQLite validation completed.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Validate SQLite'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(syncServiceProvider).pullAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Local views reloaded.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Reload Views'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isDesktop) ...[
              const SectionHeader(
                title: 'Users & Roles',
                subtitle: 'Manage local Windows users',
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () => _showCreateUserDialog(
                                context,
                                userRepo,
                                canAssignSuper: canAssignSuper,
                              ),
                              icon: const Icon(Icons.person_add_alt_outlined),
                              label: const Text('Create User'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DesktopTable(
                            minWidth: 1200,
                            columns: const [
                              DataColumn(label: Text('User')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('Local Admin')),
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
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                    await ref.read(userRepositoryProvider).signOut();
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
        userRepo.currentRole == 'super_admin' ||
        userRepo.currentRole == 'admin';
    final canEditSuper = canAssignSuper || user.role != 'super_admin';

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
          Icon(
            user.role == 'super_admin'
                ? Icons.verified_user_outlined
                : Icons.person_outline,
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Permissions - ${user.name.isEmpty ? user.email : user.name}',
          ),
          content: SizedBox(
            width: 520,
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

  Future<void> _showCreateUserDialog(
    BuildContext context,
    UserRepository userRepo, {
    required bool canAssignSuper,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var role = 'staff';
    var creating = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create User'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        validator: (value) => value == null || value.length < 6
                            ? 'Minimum 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: _roles
                            .where((r) => canAssignSuper || r != 'super_admin')
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.replaceAll('_', ' ')),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => role = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setState(() => creating = true);
                          try {
                            await userRepo.createUser(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                              name: nameController.text.trim(),
                              role: role,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User created.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create user: $e'),
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => creating = false);
                            }
                          }
                        },
                  child: creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final label = Text(
          widget.module.replaceAll('_', ' ').toUpperCase(),
          overflow: TextOverflow.ellipsis,
        );
        final switches = [
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
        ];
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: switches),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            ...switches,
          ],
        );
      },
    );
  }

  Widget _permSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Transform.scale(
            scale: 0.8,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
