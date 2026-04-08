import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../ui/responsive.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _name = 'Ahmadullah Mukhlis';
  static const _email = 'ahmadullahmukhlis2019@gmail.com';
  static const _phone = '+93784069777';
  static const _github = 'https://github.com/ahmadullahmukhlis';
  static const _linkedin = 'https://www.linkedin.com/in/ahmadullahmukhlis/';
  static const _facebook = 'https://www.facebook.com/nasarimukhlis/';
  static const _imagePath = 'assets/about/mukhlis.jpg';

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      title: 'Contact Us',
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SectionHeader(
            title: 'Contact Us',
            subtitle: 'Developer profile and contact information',
            icon: Icons.contact_mail_outlined,
          ),
          Responsive.centered(
            context,
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            _imagePath,
                            width: 220,
                            height: 280,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Flutter Developer',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        _InfoTile(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          value: _email,
                          onCopy: () => _copy(context, 'Email copied', _email),
                        ),
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          title: 'Phone',
                          value: _phone,
                          onCopy: () => _copy(context, 'Phone copied', _phone),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Social Links',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _LinkTile(
                          label: 'GitHub',
                          url: _github,
                          onCopy: () =>
                              _copy(context, 'GitHub URL copied', _github),
                        ),
                        _LinkTile(
                          label: 'LinkedIn',
                          url: _linkedin,
                          onCopy: () =>
                              _copy(context, 'LinkedIn URL copied', _linkedin),
                        ),
                        _LinkTile(
                          label: 'Facebook',
                          url: _facebook,
                          onCopy: () =>
                              _copy(context, 'Facebook URL copied', _facebook),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This page contains the developer profile, direct contact details, and social media URLs for support, collaboration, or project communication.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _copy(
    BuildContext context,
    String message,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: SelectableText(value),
      trailing: OutlinedButton(onPressed: onCopy, child: const Text('Copy')),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.label,
    required this.url,
    required this.onCopy,
  });

  final String label;
  final String url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link_outlined),
      title: Text(label),
      subtitle: SelectableText(url),
      trailing: OutlinedButton(onPressed: onCopy, child: const Text('Copy')),
    );
  }
}
