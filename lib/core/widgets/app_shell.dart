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
    final screens = const <Widget>[
      DashboardScreen(),
      CustomersScreen(),
      SuppliersScreen(),
      SalesScreen(),
      PaymentsScreen(),
      PurchasesScreen(),
      SupplierPaymentsScreen(),
      ReportsScreen(),
      UnitsScreen(),
      SettingsScreen(),
    ];

    return IndexedStack(
      index: index,
      children: screens,
    );
  }
}
