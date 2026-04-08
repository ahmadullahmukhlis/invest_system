import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/suppliers/presentation/suppliers_screen.dart';
import '../../features/supplier_payments/presentation/supplier_payments_screen.dart';
import '../../features/units/presentation/units_screen.dart';
import 'app_nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    final visibleNavItems = ref.watch(visibleNavItemsProvider);
    final screens = <Widget>[
      const DashboardScreen(),
      if (_isVisible(visibleNavItems, 'customers')) const CustomersScreen(),
      if (_isVisible(visibleNavItems, 'suppliers')) const SuppliersScreen(),
      if (_isVisible(visibleNavItems, 'sales')) const SalesScreen(),
      if (_isVisible(visibleNavItems, 'payments')) const PaymentsScreen(),
      if (_isVisible(visibleNavItems, 'purchases')) const PurchasesScreen(),
      if (_isVisible(visibleNavItems, 'supplier_payments'))
        const SupplierPaymentsScreen(),
      if (_isVisible(visibleNavItems, 'reports')) const ReportsScreen(),
      if (_isVisible(visibleNavItems, 'units')) const UnitsScreen(),
      if (_isVisible(visibleNavItems, 'settings')) const SettingsScreen(),
    ];
    final safeIndex = index.clamp(0, screens.length - 1);

    if (safeIndex != index) {
      Future.microtask(() {
        ref.read(navIndexProvider.notifier).state = safeIndex;
      });
    }

    return IndexedStack(index: safeIndex, children: screens);
  }
}

bool _isVisible(List<NavItem> items, String module) {
  return items.any((item) => item.module == module);
}
