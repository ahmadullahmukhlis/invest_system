import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../customers/data/customer_providers.dart';
import '../../customers/domain/customer.dart';
import '../../sales/data/sale_providers.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sale_detail_screen.dart';
import '../../units/data/unit_providers.dart';
import '../data/payment_providers.dart';
import '../domain/payment.dart';

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final sales = ref.watch(salesProvider);
    final payments = ref.watch(paymentsProvider)
      ..sort((a, b) => b.date.compareTo(a.date));
    final units = ref.watch(unitsProvider);

    final customer = customers.isEmpty
        ? null
        : customers.firstWhere(
            (item) => item.id == payment.customerId,
            orElse: () => customers.first,
          );
    final customerName = customer?.name ?? 'Unknown';
    final customerSales =
        sales.where((sale) => sale.customerId == payment.customerId).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final customerPayments = payments
        .where((item) => item.customerId == payment.customerId)
        .toList();
    final totalSales = customerSales.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final totalPayments = customerPayments.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final customerBalance = totalSales - totalPayments;

    Sale? linkedSale;
    if (payment.saleId != null) {
      final matches = sales.where((item) => item.id == payment.saleId);
      linkedSale = matches.isEmpty ? null : matches.first;
    }

    String unitName(String id) {
      if (units.isEmpty) return '';
      return units
          .firstWhere(
            (item) => item.id == id,
            orElse: () => units.first,
          )
          .name;
    }

    double paidForSale(String saleId) {
      return payments
          .where((item) => item.saleId == saleId)
          .fold(0.0, (sum, item) => sum + item.amount);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: 'Payment Overview',
            subtitle: 'Customer and payment details',
            icon: Icons.payments_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Info',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  InfoRow(label: 'Customer', value: customerName),
                  if (customer != null) ...[
                    InfoRow(label: 'Phone', value: customer.phone),
                    InfoRow(
                      label: 'Location',
                      value: '${customer.province}, ${customer.district}',
                    ),
                    if (customer.address != null &&
                        customer.address!.isNotEmpty)
                      InfoRow(label: 'Address', value: customer.address!),
                  ],
                  const Divider(height: 24),
                  Text(
                    'Customer Summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: 'Total Sales',
                    value: formatMoney(totalSales),
                  ),
                  InfoRow(
                    label: 'Total Payments',
                    value: formatMoney(totalPayments),
                  ),
                  InfoRow(
                    label: 'Remaining Balance',
                    value: formatMoney(customerBalance),
                    highlight: true,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Payment Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  InfoRow(label: 'Date', value: formatDate(payment.date)),
                  InfoRow(
                    label: 'Amount',
                    value: formatMoney(payment.amount),
                    highlight: true,
                  ),
                  if (payment.note != null && payment.note!.isNotEmpty)
                    InfoRow(label: 'Note', value: payment.note!),
                  if (linkedSale != null) ...[
                    const Divider(height: 24),
                    Text(
                      'Linked Sale',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InfoRow(
                      label: 'Sale Date',
                      value: formatDate(linkedSale.date),
                    ),
                    InfoRow(
                      label: 'Quantity',
                      value:
                          '${linkedSale.quantityValue} ${unitName(linkedSale.unitId)}',
                    ),
                    InfoRow(
                      label: 'Price per unit',
                      value: formatMoney(linkedSale.pricePerUnit),
                    ),
                    InfoRow(
                      label: 'Total',
                      value: formatMoney(linkedSale.totalPrice),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Customer Sales',
            subtitle: '${customerSales.length} records',
            icon: Icons.receipt_long_outlined,
          ),
          if (customerSales.isEmpty)
            const EmptyStateCard(
              title: 'No sales yet',
              subtitle: 'Sales will appear here once recorded.',
              icon: Icons.receipt_long_outlined,
            )
          else
            Column(
              children: [
                for (final sale in customerSales) ...[
                  _SaleCard(
                    sale: sale,
                    unitName: unitName(sale.unitId),
                    paid: paidForSale(sale.id),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SaleDetailScreen(sale: sale),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.unitName,
    required this.paid,
    required this.onTap,
  });

  final Sale sale;
  final String unitName;
  final double paid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final balance = sale.totalPrice - paid;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDate(sale.date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      formatMoney(sale.totalPrice),
                      style: const TextStyle(
                        color: AppColors.indigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InfoRow(
                label: 'Quantity',
                value: '${sale.quantityValue} $unitName',
              ),
              InfoRow(
                label: 'Price per unit',
                value: formatMoney(sale.pricePerUnit),
              ),
              InfoRow(
                label: 'Paid',
                value: formatMoney(paid),
              ),
              InfoRow(
                label: 'Balance',
                value: formatMoney(balance),
                highlight: true,
              ),
              if (sale.note != null && sale.note!.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  sale.note!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
