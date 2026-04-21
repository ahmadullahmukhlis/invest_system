import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/data/realtime_sync_client.dart';
import '../core/utils/network_utils.dart';
import '../data/firebase_config.dart';
import '../data/permissions.dart';
import '../data/user_repository.dart';
import 'responsive.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.syncProfileToDatabase = true,
  });

  final bool syncProfileToDatabase;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F4EF), Color(0xFFECEFF7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Responsive.centered(
              context,
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRegister ? 'Create Account' : 'Welcome Back',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to access your office purchase system.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isRegister)
                      _Field(label: 'Full name', controller: _nameController),
                    _Field(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _Field(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isRegister ? 'Create Account' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading || !Responsive.isTablet(context)
                          ? null
                          : () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister
                            ? 'Already have an account? Sign in'
                            : 'Create new account',
                      ),
                    ),
                    if (!Responsive.isTablet(context))
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Account creation is available on desktop only.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }
    if (_isRegister && name.isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }

    final online = await hasInternet();
    if (!online) {
      setState(() => _error = 'No internet connection.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await credential.user?.updateDisplayName(name);
        if (widget.syncProfileToDatabase) {
          await _ensureProfile(user: credential.user, name: name, email: email);
        }
      } else {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        if (widget.syncProfileToDatabase) {
          await _ensureProfile(
            user: credential.user,
            name: credential.user?.displayName ?? '',
            email: email,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Authentication failed.');
    } catch (_) {
      setState(() => _error = 'Authentication failed.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _ensureProfile({
    required User? user,
    required String name,
    required String email,
  }) async {
    if (user == null) return;
    final db = databaseInstanceOrNull();
    final restSync = RealtimeSyncClient.instance;
    Map<dynamic, dynamic>? existing;
    if (db != null) {
      final snapshot = await db.ref('users').child(user.uid).get();
      final value = snapshot.value;
      existing = value is Map ? value.cast<dynamic, dynamic>() : null;
    } else {
      final value = await restSync.getJson('users/${user.uid}');
      existing = value is Map ? value.cast<dynamic, dynamic>() : null;
    }
    if (existing != null) {
      if (email.toLowerCase() == UserRepository.superAdminEmail) {
        final permissions = defaultPermissionsForRole('super_admin');
        final payload = {
          'role': 'super_admin',
          'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        if (db != null) {
          await db.ref('users').child(user.uid).update(payload);
        } else {
          final merged = <String, Object?>{};
          for (final entry in existing.entries) {
            if (entry.key is String) {
              merged[entry.key as String] = entry.value;
            }
          }
          merged.addAll(payload);
          await restSync.setJson('users/${user.uid}', merged);
        }
      }
      return;
    }

    final superAdminEmail = UserRepository.superAdminEmail;
    final role = email.toLowerCase() == superAdminEmail
        ? 'super_admin'
        : 'viewer';
    final permissions = defaultPermissionsForRole(role);
    final payload = {
      'name': name,
      'email': email,
      'role': role,
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (db != null) {
      await db.ref('users').child(user.uid).set(payload);
    } else {
      await restSync.setJson('users/${user.uid}', payload);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF7F7F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
