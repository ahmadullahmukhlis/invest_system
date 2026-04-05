import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = const [
      _ModuleTile(
        title: 'Vendors',
        subtitle: 'Suppliers and contacts',
        icon: Icons.storefront,
      ),
      _ModuleTile(
        title: 'Purchases',
        subtitle: 'Orders, invoices, approvals',
        icon: Icons.receipt_long,
      ),
      _ModuleTile(
        title: 'Inventory',
        subtitle: 'Stock movements and audits',
        icon: Icons.warehouse,
      ),
      _ModuleTile(
        title: 'Approvals',
        subtitle: 'Workflow and permissions',
        icon: Icons.verified_user,
      ),
      _ModuleTile(
        title: 'Reports',
        subtitle: 'Spending, vendors, stock',
        icon: Icons.insights,
      ),
      _ModuleTile(
        title: 'Settings',
        subtitle: 'Teams and preferences',
        icon: Icons.settings,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: modules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final module = modules[index];
          return InkWell(
            onTap: () => _openModule(context, module.title),
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
                    child: Icon(module.icon, color: const Color(0xFF2A3A6A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          module.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openModule(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ModulePlaceholder(title: title),
      ),
    );
  }
}

class _ModuleTile {
  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title module is ready for the next step.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
