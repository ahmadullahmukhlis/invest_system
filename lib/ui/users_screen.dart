import 'package:flutter/material.dart';

import '../data/permissions.dart';
import '../data/user_profile.dart';
import '../data/user_repository.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.userRepository});

  final UserRepository userRepository;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    widget.userRepository.startAllUsersListener();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.userRepository.current;
    if (current == null ||
        (current.role != 'admin' && current.role != 'super_admin')) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Management')),
        body: const Center(
          child: Text('Only admins can manage users.'),
        ),
      );
    }
    final canGrantSuperAdmin = current.role == 'super_admin';

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: StreamBuilder<List<UserProfile>>(
        stream: widget.userRepository.allUsersStream,
        builder: (context, snapshot) {
          final users = snapshot.data ?? const [];
          if (users.isEmpty) {
            return const Center(child: Text('No users yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE7EAF6),
                      child: Text(
                        user.name.isEmpty ? 'U' : user.name[0].toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isEmpty ? user.email : user.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              DropdownButton<String>(
                                value: user.role,
                                items: [
                                  if (canGrantSuperAdmin)
                                    const DropdownMenuItem(
                                      value: 'super_admin',
                                      child: Text('Super Admin'),
                                    ),
                                  const DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Admin'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'manager',
                                    child: Text('Manager'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'staff',
                                    child: Text('Staff'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'viewer',
                                    child: Text('Viewer'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  if (value == 'super_admin' &&
                                      !canGrantSuperAdmin) {
                                    return;
                                  }
                                  widget.userRepository
                                      .updateUserRole(user.uid, value);
                                },
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => _editPermissions(user),
                                child: const Text('Permissions'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editPermissions(UserProfile user) async {
    final permissions = Map<String, PermissionSet>.from(user.permissions);
    for (final module in modules) {
      permissions.putIfAbsent(
        module,
        () => PermissionSet(view: false, create: false, edit: false, remove: false),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Permissions: ${user.name.isEmpty ? user.email : user.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final module in modules) ...[
                    Text(
                      module.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _permChip(
                          label: 'View',
                          value: permissions[module]!.view,
                          onChanged: (value) {
                            setModalState(() {
                              permissions[module] =
                                  permissions[module]!.copyWith(view: value);
                            });
                          },
                        ),
                        _permChip(
                          label: 'Create',
                          value: permissions[module]!.create,
                          onChanged: (value) {
                            setModalState(() {
                              permissions[module] =
                                  permissions[module]!.copyWith(create: value);
                            });
                          },
                        ),
                        _permChip(
                          label: 'Edit',
                          value: permissions[module]!.edit,
                          onChanged: (value) {
                            setModalState(() {
                              permissions[module] =
                                  permissions[module]!.copyWith(edit: value);
                            });
                          },
                        ),
                        _permChip(
                          label: 'Delete',
                          value: permissions[module]!.remove,
                          onChanged: (value) {
                            setModalState(() {
                              permissions[module] =
                                  permissions[module]!.copyWith(remove: value);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: () async {
                      await widget.userRepository
                          .updateUserPermissions(user.uid, permissions);
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Save Permissions'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _permChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }
}
