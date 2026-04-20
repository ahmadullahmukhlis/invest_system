import 'package:flutter/material.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firebase Setup Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'This build needs Firebase configuration for the '
                          'current desktop platform.',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Next steps:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1) Run `flutterfire configure` and enable Windows/macOS.\n'
                  '2) Replace the placeholder values in `lib/firebase_options.dart`.\n'
                  '3) Rebuild the desktop app.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
