import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../../supplier_payments/data/supplier_payment_repository.dart';
import '../../supplier_payments/domain/supplier_payment.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../units/data/unit_providers.dart';
import '../domain/purchase.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    final units = ref.watch(unitsProvider);
    final payments = ref.watch(supplierPaymentsProvider)
      ..sort((a, b) => b.date.compareTo(a.date));

    final supplierName = suppliers.isEmpty
        ? 'Unknown'
        : suppliers
            .firstWhere(
              (item) => item.id == purchase.supplierId,
              orElse: () => suppliers.first,
            )
            .name;
    final unitName = units.isEmpty
        ? ''
        : units
            .firstWhere(
              (item) => item.id == purchase.unitId,
              orElse: () => units.first,
            )
            .name;

    final related = payments.where((p) => p.purchaseId == purchase.id).toList();
    final paid = related.fold(0.0, (sum, item) => sum + item.amount);
    final balance = purchase.totalPrice - paid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Details'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<SupplierPayment>(
                context: context,
                builder: (_) => _PaymentForPurchaseDialog(
                  supplierId: purchase.supplierId,
                  purchase: purchase,
                  balance: balance,
                ),
              );
              if (created != null) {
                await ref
                    .read(supplierPaymentRepositoryProvider)
                    .upsert(created);
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
                  Text('Supplier: $supplierName'),
                  Text('Date: ${formatDate(purchase.date)}'),
                  const Divider(),
                  Text('Quantity: ${purchase.quantityValue} $unitName'),
                  Text('Price per unit: ${formatMoney(purchase.pricePerUnit)}'),
                  Text('Total: ${formatMoney(purchase.totalPrice)}'),
                  Text('Paid: ${formatMoney(paid)}'),
                  Text('Balance: ${formatMoney(balance)}'),
                  if (purchase.note != null && purchase.note!.isNotEmpty) ...[
                    const Divider(),
                    Text('Note: ${purchase.note}'),
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

class _PaymentForPurchaseDialog extends StatefulWidget {
  const _PaymentForPurchaseDialog({
    required this.supplierId,
    required this.purchase,
    required this.balance,
  });

  final String supplierId;
  final Purchase purchase;
  final double balance;

  @override
  State<_PaymentForPurchaseDialog> createState() =>
      _PaymentForPurchaseDialogState();
}

class _PaymentForPurchaseDialogState extends State<_PaymentForPurchaseDialog> {
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
      title: const Text('Add Supplier Payment'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Purchase Total'),
                  trailing: Text(formatMoney(widget.purchase.totalPrice)),
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
              SupplierPayment(
                id: '',
                supplierId: widget.supplierId,
                purchaseId: widget.purchase.id,
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
