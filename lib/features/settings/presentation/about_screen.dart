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
  static const _bio =
      'Flutter developer focused on mobile application development, project delivery, and direct collaboration for software support and product communication.';

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

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
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              _ProfileImageCard(),
                              SizedBox(width: 24),
                              Expanded(child: _ProfileDetails()),
                            ],
                          )
                        : const Column(
                            children: [
                              _ProfileImageCard(),
                              SizedBox(height: 20),
                              _ProfileDetails(),
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
                          'Bio',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _bio,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.5),
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
                      children: const [
                        _SectionTitle('Social Links'),
                        SizedBox(height: 12),
                        _LinkTile(label: 'GitHub', url: _github),
                        _LinkTile(label: 'LinkedIn', url: _linkedin),
                        _LinkTile(label: 'Facebook', url: _facebook),
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

  static Future<void> copy(
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

class _ProfileImageCard extends StatelessWidget {
  const _ProfileImageCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        AboutScreen._imagePath,
        width: 220,
        height: 280,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 220,
          height: 280,
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Icon(Icons.person_outline, size: 72),
        ),
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AboutScreen._name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Flutter Developer',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        _InfoTile(
          icon: Icons.email_outlined,
          title: 'Email',
          value: AboutScreen._email,
          copiedMessage: 'Email copied',
        ),
        _InfoTile(
          icon: Icons.phone_outlined,
          title: 'Phone',
          value: AboutScreen._phone,
          copiedMessage: 'Phone copied',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.copiedMessage,
  });

  final IconData icon;
  final String title;
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: SelectableText(value),
      trailing: OutlinedButton(
        onPressed: () => AboutScreen.copy(context, copiedMessage, value),
        child: const Text('Copy'),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link_outlined),
      title: Text(label),
      subtitle: SelectableText(url),
      trailing: OutlinedButton(
        onPressed: () => AboutScreen.copy(context, '$label URL copied', url),
        child: const Text('Copy'),
      ),
    );
  }
}
