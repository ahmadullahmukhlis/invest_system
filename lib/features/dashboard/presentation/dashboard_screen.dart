import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../customers/data/customer_providers.dart';
import '../../payments/data/payment_providers.dart';
import '../../sales/data/sale_providers.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSales = ref.watch(totalSalesProvider);
    final totalSalesToday = ref.watch(totalSalesTodayProvider);
    final totalPurchases = ref.watch(totalPurchasesProvider);
    final totalPurchasesToday = ref.watch(totalPurchasesTodayProvider);
    final totalPaymentsReceived = ref.watch(totalPaymentsReceivedProvider);
    final totalPaymentsReceivedToday =
        ref.watch(totalPaymentsReceivedTodayProvider);
    final totalPaymentsPaid = ref.watch(totalPaymentsPaidProvider);
    final totalPaymentsPaidToday = ref.watch(totalPaymentsPaidTodayProvider);
    final totalCustomerBalance = ref.watch(totalCustomerBalanceProvider);
    final totalSupplierBalance = ref.watch(totalSupplierBalanceProvider);

    final topCustomers = ref.watch(topCustomersProvider);
    final customers = ref.watch(customersProvider);
    final sales = ref.watch(salesProvider);
    final payments = ref.watch(paymentsProvider);
    final suppliers = ref.watch(suppliersProvider);
    final supplierPayments = ref.watch(supplierPaymentsProvider);

    final recentSales = [...sales]..sort((a, b) => b.date.compareTo(a.date));
    final recentPayments = [...payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentSupplierPayments = [...supplierPayments]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                title: 'Total Sales Today',
                value: formatMoney(totalSalesToday),
                subtitle: 'All time: ${formatMoney(totalSales)}',
                color: AppColors.accent,
              ),
              _MetricCard(
                title: 'Total Purchases Today',
                value: formatMoney(totalPurchasesToday),
                subtitle: 'All time: ${formatMoney(totalPurchases)}',
                color: AppColors.indigo,
              ),
              _MetricCard(
                title: 'Cash Received Today',
                value: formatMoney(totalPaymentsReceivedToday),
                subtitle: 'All time: ${formatMoney(totalPaymentsReceived)}',
                color: AppColors.success,
              ),
              _MetricCard(
                title: 'Cash Paid Today',
                value: formatMoney(totalPaymentsPaidToday),
                subtitle: 'All time: ${formatMoney(totalPaymentsPaid)}',
                color: AppColors.danger,
              ),
              _MetricCard(
                title: 'Customer Balances (Sum)',
                value: formatMoney(totalCustomerBalance),
                subtitle: 'Outstanding receivables',
                color: AppColors.amber,
              ),
              _MetricCard(
                title: 'Supplier Balances (Sum)',
                value: formatMoney(totalSupplierBalance),
                subtitle: 'Outstanding payables',
                color: AppColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Top Customers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _TopCustomersCard(topCustomers: topCustomers),
          const SizedBox(height: 24),
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _RecentTransactionsCard(
            sales: recentSales.take(5).toList(),
            payments: recentPayments.take(5).toList(),
            customers: customers,
            suppliers: suppliers,
            supplierPayments: recentSupplierPayments.take(5).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        color: AppColors.card,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopCustomersCard extends StatelessWidget {
  const _TopCustomersCard({required this.topCustomers});

  final List<Map<String, Object>> topCustomers;

  @override
  Widget build(BuildContext context) {
    if (topCustomers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No sales yet.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final item in topCustomers)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text((item['customer'] as dynamic).name),
                trailing: Text(formatMoney(item['total'] as double)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.sales,
    required this.payments,
    required this.customers,
    required this.suppliers,
    required this.supplierPayments,
  });

  final List<dynamic> sales;
  final List<dynamic> payments;
  final List<dynamic> customers;
  final List<dynamic> suppliers;
  final List<dynamic> supplierPayments;

  @override
  Widget build(BuildContext context) {
    String customerName(String id) {
      if (customers.isEmpty) return 'Unknown';
      return customers
          .firstWhere(
            (customer) => customer.id == id,
            orElse: () => customers.first,
          )
          .name;
    }

    String supplierName(String id) {
      if (suppliers.isEmpty) return 'Unknown';
      return suppliers
          .firstWhere(
            (supplier) => supplier.id == id,
            orElse: () => suppliers.first,
          )
          .name;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...sales.map(
              (sale) => ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('Sale • ${formatDate(sale.date)}'),
                subtitle: Text(customerName(sale.customerId)),
                trailing: Text(formatMoney(sale.totalPrice)),
              ),
            ),
            ...payments.map(
              (payment) => ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('Payment • ${formatDate(payment.date)}'),
                subtitle: Text(customerName(payment.customerId)),
                trailing: Text(formatMoney(payment.amount)),
              ),
            ),
            ...supplierPayments.map(
              (payment) => ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text('Supplier Payment • ${formatDate(payment.date)}'),
                subtitle: Text(supplierName(payment.supplierId)),
                trailing: Text(formatMoney(payment.amount)),
              ),
            ),
            if (sales.isEmpty && payments.isEmpty && supplierPayments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No recent transactions.'),
              ),
          ],
        ),
      ),
    );
  }
}
