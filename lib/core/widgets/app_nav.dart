import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavItem {
  const NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

const navItems = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_outlined),
  NavItem('Customers', Icons.people_alt_outlined),
  NavItem('Suppliers', Icons.storefront_outlined),
  NavItem('Sales', Icons.receipt_long_outlined),
  NavItem('Payments', Icons.payments_outlined),
  NavItem('Purchases', Icons.shopping_cart_outlined),
  NavItem('Supplier Pay', Icons.account_balance_wallet_outlined),
  NavItem('Reports', Icons.assessment_outlined),
  NavItem('Units', Icons.scale_outlined),
];

final navIndexProvider = StateProvider<int>((ref) => 0);
