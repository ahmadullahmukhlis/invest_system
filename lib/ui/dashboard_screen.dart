import 'package:flutter/material.dart';

import '../data/customer_repository.dart';
import '../data/product_repository.dart';
import '../data/purchase_repository.dart';
import '../data/vendor_repository.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.customerRepository,
    required this.productRepository,
    required this.vendorRepository,
    required this.purchaseRepository,
  });

  final CustomerRepository customerRepository;
  final ProductRepository productRepository;
  final VendorRepository vendorRepository;
  final PurchaseRepository purchaseRepository;

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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Office Purchase System',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Track customers, products, and purchases in one place.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              _StatusCard(
                title: 'Sync Status',
                subtitle: 'Customer & product data',
                leading: Icons.cloud_done,
                trailing: StreamBuilder<Object>(
                  stream: customerRepository.stream,
                  builder: (context, snapshot) {
                    final online = customerRepository.isOnline &&
                        productRepository.isOnline &&
                        vendorRepository.isOnline &&
                        purchaseRepository.isOnline;
                    return Text(online ? 'Online' : 'Offline');
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Customers',
                      stream: customerRepository.stream,
                      icon: Icons.people_alt,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      title: 'Products',
                      stream: productRepository.stream,
                      icon: Icons.inventory,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Vendors',
                      stream: vendorRepository.stream,
                      icon: Icons.storefront,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      title: 'Purchases',
                      stream: purchaseRepository.stream,
                      icon: Icons.receipt_long,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _QuickAction(label: 'New Purchase', icon: Icons.receipt_long),
                  _QuickAction(label: 'Add Vendor', icon: Icons.store),
                  _QuickAction(label: 'Stock Check', icon: Icons.qr_code),
                  _QuickAction(label: 'Reports', icon: Icons.insights),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEEF1FA),
            child: Icon(leading, color: const Color(0xFF2A3A6A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _MetricCard<T> extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.stream,
    required this.icon,
  });

  final String title;
  final Stream<List<T>> stream;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E3DE)),
      ),
      child: StreamBuilder<List<T>>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF2A3A6A)),
              const SizedBox(height: 12),
              Text('$count', style: theme.textTheme.headlineSmall),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2A3A6A)),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
