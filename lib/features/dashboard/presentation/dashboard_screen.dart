import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../customers/data/customer_providers.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_ledger_screen.dart';
import '../../payments/data/payment_providers.dart';
import '../../payments/domain/payment.dart';
import '../../sales/data/sale_providers.dart';
import '../../sales/domain/sale.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../suppliers/domain/supplier.dart';
import '../../suppliers/presentation/supplier_ledger_screen.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../../supplier_payments/domain/supplier_payment.dart';
import '../../sales/presentation/sale_detail_screen.dart';
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
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Stats Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width < 420
                    ? 1
                    : width < 900
                        ? 2
                        : 3;
                const spacing = 12.0;
                final itemWidth =
                    (width - (columns - 1) * spacing) / columns;
                final metrics = [
                  _MetricData(
                    title: 'Today\'s Sales',
                    value: formatMoney(totalSalesToday),
                    subtitle: 'Total: ${formatMoney(totalSales)}',
                    icon: Icons.trending_up,
                    color: AppColors.indigo,
                  ),
                  _MetricData(
                    title: 'Today\'s Purchases',
                    value: formatMoney(totalPurchasesToday),
                    subtitle: 'Total: ${formatMoney(totalPurchases)}',
                    icon: Icons.shopping_cart,
                    color: AppColors.indigo,
                  ),
                  _MetricData(
                    title: 'Cash Received',
                    value: formatMoney(totalPaymentsReceivedToday),
                    subtitle: 'Total: ${formatMoney(totalPaymentsReceived)}',
                    icon: Icons.arrow_downward,
                    color: AppColors.indigo,
                  ),
                  _MetricData(
                    title: 'Cash Paid',
                    value: formatMoney(totalPaymentsPaidToday),
                    subtitle: 'Total: ${formatMoney(totalPaymentsPaid)}',
                    icon: Icons.arrow_upward,
                    color: AppColors.indigo,
                  ),
                  _MetricData(
                    title: 'Receivables',
                    value: formatMoney(totalCustomerBalance),
                    subtitle: 'From customers',
                    icon: Icons.people,
                    color: AppColors.indigo,
                  ),
                  _MetricData(
                    title: 'Payables',
                    value: formatMoney(totalSupplierBalance),
                    subtitle: 'To suppliers',
                    icon: Icons.business,
                    color: AppColors.indigo,
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in metrics)
                      SizedBox(
                        width: itemWidth,
                        child: _MetricCard(
                          title: item.title,
                          value: item.value,
                          subtitle: item.subtitle,
                          icon: item.icon,
                          color: item.color,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Top Customers Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: AppColors.indigo, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Top Customers',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _TopCustomersCard(topCustomers: topCustomers),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Transactions Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: AppColors.indigo, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Recent Transactions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _RecentTransactionsCard(
                  sales: recentSales.take(5).toList(),
                  payments: recentPayments.take(5).toList(),
                  customers: customers,
                  suppliers: suppliers,
                  supplierPayments: recentSupplierPayments.take(5).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxHeight < 120 || constraints.maxWidth < 160;
        final padding = isCompact ? 12.0 : 16.0;
        final valueSize = isCompact ? 18.0 : 24.0;
        final iconSize = isCompact ? 18.0 : 20.0;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: iconSize),
                    ),
                    if (!isCompact)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isCompact ? 6 : 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: valueSize,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopCustomersCard extends StatelessWidget {
  const _TopCustomersCard({required this.topCustomers});

  final List<Map<String, Object>> topCustomers;

  @override
  Widget build(BuildContext context) {
    if (topCustomers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(
                  'No sales yet',
                  style: TextStyle(color: AppColors.success),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < topCustomers.length; i++)
            _buildCustomerTile(
              context,
              topCustomers[i],
              i + 1,
              isLast: i == topCustomers.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerTile(BuildContext context, Map<String, Object> item, int rank, {required bool isLast}) {
    final customer = item['customer'] as Customer;
    final total = item['total'] as double;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerLedgerScreen(customer: customer),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.muted.withOpacity(0.15)),
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: AppColors.card,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (customer.phone != null)
                      Text(
                        customer.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'Total spent',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
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

  final List<Sale> sales;
  final List<Payment> payments;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final List<SupplierPayment> supplierPayments;

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

    Customer? customerById(String id) {
      for (final customer in customers) {
        if (customer.id == id) return customer;
      }
      return null;
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

    Supplier? supplierById(String id) {
      for (final supplier in suppliers) {
        if (supplier.id == id) return supplier;
      }
      return null;
    }

    final allTransactions = <Widget>[];

    for (final sale in sales) {
      allTransactions.add(
        _TransactionTile(
          icon: Icons.receipt_long_outlined,
          iconColor: AppColors.accent,
          title: 'Sale',
          date: sale.date,
          subtitle: customerName(sale.customerId),
          amount: sale.totalPrice,
          amountColor: AppColors.success,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SaleDetailScreen(sale: sale),
              ),
            );
          },
        ),
      );
    }

    for (final payment in payments) {
      allTransactions.add(
        _TransactionTile(
          icon: Icons.payments_outlined,
          iconColor: AppColors.success,
          title: 'Payment Received',
          date: payment.date,
          subtitle: customerName(payment.customerId),
          amount: payment.amount,
          amountColor: AppColors.success,
          onTap: () {
            final customer = customerById(payment.customerId);
            if (customer == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer not found.')),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerLedgerScreen(customer: customer),
              ),
            );
          },
        ),
      );
    }

    for (final payment in supplierPayments) {
      allTransactions.add(
        _TransactionTile(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.danger,
          title: 'Supplier Payment',
          date: payment.date,
          subtitle: supplierName(payment.supplierId),
          amount: payment.amount,
          amountColor: AppColors.danger,
          onTap: () {
            final supplier = supplierById(payment.supplierId);
            if (supplier == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Supplier not found.')),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SupplierLedgerScreen(supplier: supplier),
              ),
            );
          },
        ),
      );
    }

    if (allTransactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(
                  'No recent transactions',
                  style: TextStyle(color: AppColors.success),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: allTransactions,
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final DateTime date;
  final String subtitle;
  final double amount;
  final Color amountColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.muted.withOpacity(0.15)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatMoney(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: amountColor,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      title.contains('Payment') ? 'Amount' : 'Total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
