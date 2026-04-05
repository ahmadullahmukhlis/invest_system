import 'package:flutter/material.dart';

import '../data/customer_repository.dart';
import '../data/permissions.dart';
import '../data/product_repository.dart';
import '../data/purchase_repository.dart';
import '../data/user_repository.dart';
import '../data/vendor_repository.dart';
import 'approvals_screen.dart';
import 'inventory_screen.dart';
import 'purchases_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'vendors_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.vendorRepository,
    required this.purchaseRepository,
    required this.productRepository,
    required this.customerRepository,
    required this.userRepository,
    required this.permissions,
    required this.role,
  });

  final VendorRepository vendorRepository;
  final PurchaseRepository purchaseRepository;
  final ProductRepository productRepository;
  final CustomerRepository customerRepository;
  final UserRepository userRepository;
  final Map<String, PermissionSet> permissions;
  final String role;

  @override
  Widget build(BuildContext context) {
    bool canView(String module) {
      if (role == 'super_admin') return true;
      return permissions[module]?.view ?? false;
    }

    final modules = <_ModuleTile>[
      if (canView('vendors'))
        _ModuleTile(
          title: 'Vendors',
          subtitle: 'Suppliers and contacts',
          icon: Icons.storefront,
          builder: (_) => VendorsScreen(
            repository: vendorRepository,
            permissions: permissions['vendors'],
          ),
        ),
      if (canView('purchases'))
        _ModuleTile(
          title: 'Purchases',
          subtitle: 'Orders, invoices, approvals',
          icon: Icons.receipt_long,
          builder: (_) => PurchasesScreen(
            repository: purchaseRepository,
            permissions: permissions['purchases'],
          ),
        ),
      if (canView('inventory'))
        _ModuleTile(
          title: 'Inventory',
          subtitle: 'Stock movements and audits',
          icon: Icons.warehouse,
          builder: (_) => InventoryScreen(
            repository: productRepository,
            permissions: permissions['inventory'],
          ),
        ),
      if (canView('approvals'))
        _ModuleTile(
          title: 'Approvals',
          subtitle: 'Workflow and permissions',
          icon: Icons.verified_user,
          builder: (_) => const ApprovalsScreen(),
        ),
      if (canView('reports'))
        _ModuleTile(
          title: 'Reports',
          subtitle: 'Spending, vendors, stock',
          icon: Icons.insights,
          builder: (_) => ReportsScreen(
            customerRepository: customerRepository,
            productRepository: productRepository,
            purchaseRepository: purchaseRepository,
          ),
        ),
      if (canView('settings'))
        _ModuleTile(
          title: 'Settings',
          subtitle: 'Teams and preferences',
          icon: Icons.settings,
          builder: (_) => SettingsScreen(userRepository: userRepository),
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
            onTap: () => _openModule(context, module.builder),
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

  void _openModule(
    BuildContext context,
    WidgetBuilder builder,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: builder),
    );
  }
}

class _ModuleTile {
  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}
