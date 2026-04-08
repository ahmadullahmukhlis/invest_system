import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/permissions.dart';
import '../../data/user_providers.dart';

class NavItem {
  const NavItem(this.label, this.icon, {this.module});

  final String label;
  final IconData icon;
  final String? module;
}

const navItems = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_outlined),
  NavItem('Customers', Icons.people_alt_outlined, module: 'customers'),
  NavItem('Suppliers', Icons.storefront_outlined, module: 'suppliers'),
  NavItem('Sales', Icons.receipt_long_outlined, module: 'sales'),
  NavItem('Payments', Icons.payments_outlined, module: 'payments'),
  NavItem('Purchases', Icons.shopping_cart_outlined, module: 'purchases'),
  NavItem(
    'Supplier Pay',
    Icons.account_balance_wallet_outlined,
    module: 'supplier_payments',
  ),
  NavItem('Reports', Icons.assessment_outlined, module: 'reports'),
  NavItem('Units', Icons.scale_outlined, module: 'units'),
  NavItem('Settings', Icons.settings_outlined, module: 'settings'),
];

final navIndexProvider = StateProvider<int>((ref) => 0);

final visibleNavItemsProvider = Provider<List<NavItem>>((ref) {
  ref.watch(currentUserProfileProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final role = userRepo.currentRole;
  final permissions =
      userRepo.current?.permissions ?? defaultPermissionsForRole(role);

  bool canView(String? module) {
    if (module == null) return true;
    if (role == 'admin' || role == 'super_admin') return true;
    return permissions[module]?.view ?? false;
  }

  return navItems.where((item) => canView(item.module)).toList();
});
