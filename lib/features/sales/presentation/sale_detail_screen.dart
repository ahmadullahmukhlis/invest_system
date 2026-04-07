import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../customers/data/customer_providers.dart';
import '../../payments/data/payment_providers.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment.dart';
import '../../units/data/unit_providers.dart';
import '../domain/sale.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final units = ref.watch(unitsProvider);
    final payments = ref.watch(paymentsProvider)
      ..sort((a, b) => b.date.compareTo(a.date));

    final customerName = customers.isEmpty
        ? 'Unknown'
        : customers
            .firstWhere(
              (item) => item.id == sale.customerId,
              orElse: () => customers.first,
            )
            .name;
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
          IconButton(
            onPressed: () async {
              final created = await showDialog<Payment>(
                context: context,
                builder: (_) => _PaymentForSaleDialog(
                  customerId: sale.customerId,
                  sale: sale,
                  balance: balance,
                ),
              );
              if (created != null) {
                await ref.read(paymentRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_card_outlined),
            tooltip: 'Add Payment',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: $customerName'),
                  Text('Date: ${formatDate(sale.date)}'),
                  const Divider(),
                  Text('Quantity: ${sale.quantityValue} $unitName'),
                  Text('Price per unit: ${formatMoney(sale.pricePerUnit)}'),
                  Text('Total: ${formatMoney(sale.totalPrice)}'),
                  Text('Paid: ${formatMoney(paid)}'),
                  Text('Balance: ${formatMoney(balance)}'),
                  if (sale.note != null && sale.note!.isNotEmpty) ...[
                    const Divider(),
                    Text('Note: ${sale.note}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Payments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: related.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No payments yet.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final payment = related[index];
                      return ListTile(
                        title: Text(formatMoney(payment.amount)),
                        subtitle: Text(formatDate(payment.date)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentForSaleDialog extends StatefulWidget {
  const _PaymentForSaleDialog({
    required this.customerId,
    required this.sale,
    required this.balance,
  });

  final String customerId;
  final Sale sale;
  final double balance;

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
