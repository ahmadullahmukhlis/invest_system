import 'package:flutter/material.dart';

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
    if (current == null || current.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('User Management')),
        body: const Center(
          child: Text('Only admins can manage users.'),
        ),
      );
    }

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
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: user.role,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        widget.userRepository.updateUserRole(user.uid, value);
                      },
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
}
