import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/user_repository.dart';
import 'users_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.userRepository});

  final UserRepository userRepository;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder(
      stream: userRepository.currentUserStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
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
                        (user?.email?.isNotEmpty ?? false)
                            ? user!.email![0].toUpperCase()
                            : 'U',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name.isNotEmpty == true
                                ? profile!.name
                                : (user?.email ?? 'Unknown User'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${profile?.role ?? 'staff'} account',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (profile?.role == 'admin')
                _SettingsTile(
                  title: 'User Management',
                  subtitle: 'Invite, edit roles, permissions',
                  icon: Icons.group,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UsersScreen(userRepository: userRepository),
                    ),
                  ),
                ),
              if (profile?.role == 'admin') const SizedBox(height: 12),
              _SettingsTile(
                title: 'Team Roles',
                subtitle: 'Admin, manager, staff',
                icon: Icons.security,
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                title: 'Notifications',
                subtitle: 'Purchase alerts and approvals',
                icon: Icons.notifications,
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                title: 'Data Sync',
                subtitle: 'Offline-first enabled',
                icon: Icons.sync,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
              child: Icon(icon, color: const Color(0xFF2A3A6A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
