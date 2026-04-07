import 'package:flutter/material.dart';

import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/suppliers/presentation/suppliers_screen.dart';
import '../../features/supplier_payments/presentation/supplier_payments_screen.dart';
import '../../features/units/presentation/units_screen.dart';
import '../theme/app_colors.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _items = const <_NavItem>[
    _NavItem('Dashboard', Icons.dashboard_outlined),
    _NavItem('Customers', Icons.people_alt_outlined),
    _NavItem('Suppliers', Icons.storefront_outlined),
    _NavItem('Sales', Icons.receipt_long_outlined),
    _NavItem('Payments', Icons.payments_outlined),
    _NavItem('Purchases', Icons.shopping_cart_outlined),
    _NavItem('Supplier Pay', Icons.account_balance_wallet_outlined),
    _NavItem('Reports', Icons.assessment_outlined),
    _NavItem('Units', Icons.scale_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const DashboardScreen(),
      const CustomersScreen(),
      const SuppliersScreen(),
      const SalesScreen(),
      const PaymentsScreen(),
      const PurchasesScreen(),
      const SupplierPaymentsScreen(),
      const ReportsScreen(),
      const UnitsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Scaffold(
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  backgroundColor: AppColors.card,
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  destinations: [
                    for (final item in _items)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              Expanded(child: screens[_index]),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  destinations: [
                    for (final item in _items)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
