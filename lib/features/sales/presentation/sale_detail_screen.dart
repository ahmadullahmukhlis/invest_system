import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/theme/app_colors.dart';
import '../../customers/data/customer_providers.dart';
import '../../payments/data/payment_providers.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment.dart';
import '../../units/data/unit_providers.dart';
import '../data/sale_providers.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final units = ref.watch(unitsProvider);
    final allSales = ref.watch(salesProvider);
    final payments = ref.watch(paymentsProvider)
      ..sort((a, b) => b.date.compareTo(a.date));

    final customer = customers.isEmpty
        ? null
        : customers.firstWhere(
            (item) => item.id == sale.customerId,
            orElse: () => customers.first,
          );
    final customerName = customer?.name ?? 'Unknown';
    final unitName = units.isEmpty
        ? ''
        : units
            .firstWhere(
              (item) => item.id == sale.unitId,
              orElse: () => units.first,
            )
            .name;

    final related = payments.where((p) => p.saleId == sale.id).toList();
    final paid = related.fold(0.0, (sum, item) => sum + item.amount);
    final balance = sale.totalPrice - paid;
    final lastPaymentDate =
        related.isEmpty ? null : related.first.date;
    final customerSalesTotal = allSales
        .where((item) => item.customerId == sale.customerId)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final customerPaymentsTotal = payments
        .where((item) => item.customerId == sale.customerId)
        .fold(0.0, (sum, item) => sum + item.amount);
    final customerBalance = customerSalesTotal - customerPaymentsTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Details'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          FutureBuilder<bool>(
            future: ref.read(saleRepositoryProvider).canEdit(sale.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final updated = await showDialog<Sale>(
                    context: context,
                    builder: (_) => _EditSaleDialog(
                      sale: sale,
                    ),
                  );
                  if (updated != null) {
                    await ref.read(saleRepositoryProvider).upsert(updated);
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
              );
            },
          ),
          IconButton(
            onPressed: () async {
              final created = await showDialog<Payment>(
                context: context,
                builder: (_) => _PaymentForSaleDialog(
                  customerId: sale.customerId,
                  sale: sale,
                  balance: balance,
                  customerTotalSales: customerSalesTotal,
                  customerTotalPayments: customerPaymentsTotal,
                  customerRemaining: customerBalance,
                ),
              );
              if (created != null) {
                await ref.read(paymentRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_card_outlined),
            tooltip: 'Add Payment',
          ),
          FutureBuilder<bool>(
            future: ref.read(saleRepositoryProvider).canEdit(sale.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final confirm = await _confirmDelete(context);
                  if (confirm) {
                    await ref.read(saleRepositoryProvider).deleteById(sale.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
          const SectionHeader(
            title: 'Sale Overview',
            subtitle: 'Customer and sale details',
            icon: Icons.receipt_long_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Info',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  InfoRow(label: 'Customer', value: customerName),
                  if (customer != null) ...[
                    InfoRow(label: 'Phone', value: customer.phone),
                    InfoRow(
                      label: 'Location',
                      value:
                          '${customer.province}, ${customer.district}',
                    ),
                    if (customer.address != null &&
                        customer.address!.isNotEmpty)
                      InfoRow(label: 'Address', value: customer.address!),
                  ],
                  const Divider(height: 24),
                  Text('Customer Summary',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: 'Total Sales',
                    value: formatMoney(customerSalesTotal),
                  ),
                  InfoRow(
                    label: 'Total Payments',
                    value: formatMoney(customerPaymentsTotal),
                  ),
                  InfoRow(
                    label: 'Remaining Balance',
                    value: formatMoney(customerBalance),
                    highlight: true,
                  ),
                  const Divider(height: 24),
                  Text('Sale Details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  InfoRow(label: 'Date', value: formatDate(sale.date)),
                  InfoRow(
                      label: 'Quantity',
                      value: '${sale.quantityValue} $unitName'),
                  InfoRow(
                    label: 'Price per unit',
                    value: formatMoney(sale.pricePerUnit),
                  ),
                  InfoRow(label: 'Total', value: formatMoney(sale.totalPrice)),
                  InfoRow(label: 'Paid', value: formatMoney(paid)),
                  InfoRow(
                    label: 'Balance',
                    value: formatMoney(balance),
                    highlight: true,
                  ),
                  InfoRow(
                    label: 'Payments Count',
                    value: related.length.toString(),
                  ),
                  if (lastPaymentDate != null)
                    InfoRow(
                      label: 'Last Payment',
                      value: formatDate(lastPaymentDate),
                    ),
                  if (sale.note != null && sale.note!.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('Note',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(sale.note!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Payments',
            subtitle: 'Payments received for this sale',
            icon: Icons.payments_outlined,
          ),
          if (related.isEmpty)
            const EmptyStateCard(
              title: 'No payments yet',
              subtitle: 'Add a payment to close this sale.',
              icon: Icons.payments_outlined,
            )
          else
            Column(
              children: [
                for (final payment in related) ...[
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.payments_outlined,
                          color: AppColors.success,
                          size: 18,
                        ),
                      ),
                      title: Text(formatMoney(payment.amount)),
                      subtitle: Text(formatDate(payment.date)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSaleDialog extends StatefulWidget {
  const _EditSaleDialog({required this.sale});

  final Sale sale;

  @override
  State<_EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends State<_EditSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.sale.date;
    _quantity.text = widget.sale.quantityValue.toString();
    _price.text = widget.sale.pricePerUnit.toString();
    _note.text = widget.sale.note ?? '';
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Sale'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _quantity,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Quantity must be > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price per unit'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Price must be > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(formatDate(_date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.date_range_outlined),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: _date,
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final quantity = double.parse(_quantity.text);
            final price = double.parse(_price.text);
            final total = quantity * price;
            Navigator.pop(
              context,
              widget.sale.copyWith(
                date: _date,
                quantityValue: quantity,
                pricePerUnit: price,
                totalPrice: total,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PaymentForSaleDialog extends StatefulWidget {
  const _PaymentForSaleDialog({
    required this.customerId,
    required this.sale,
    required this.balance,
    required this.customerTotalSales,
    required this.customerTotalPayments,
    required this.customerRemaining,
  });

  final String customerId;
  final Sale sale;
  final double balance;
  final double customerTotalSales;
  final double customerTotalPayments;
  final double customerRemaining;

  @override
  State<_PaymentForSaleDialog> createState() => _PaymentForSaleDialogState();
}

class _PaymentForSaleDialogState extends State<_PaymentForSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Total Sales'),
                  trailing: Text(formatMoney(widget.customerTotalSales)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Total Payments'),
                  trailing: Text(formatMoney(widget.customerTotalPayments)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Remaining Balance'),
                  trailing: Text(formatMoney(widget.customerRemaining)),
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sale Total'),
                  trailing: Text(formatMoney(widget.sale.totalPrice)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remaining Balance'),
                  trailing: Text(formatMoney(widget.balance)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Amount must be > 0';
                    }
                    if (parsed > widget.balance) {
                      return 'Payment exceeds balance';
                    }
                    if (parsed > widget.customerRemaining) {
                      return 'Payment exceeds customer remaining balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(formatDate(_date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.date_range_outlined),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: _date,
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              Payment(
                id: '',
                customerId: widget.customerId,
                saleId: widget.sale.id,
                date: _date,
                amount: double.parse(_amount.text),
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete sale?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
