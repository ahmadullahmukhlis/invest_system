import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../purchases/domain/purchase.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/supplier_payment_providers.dart';
import '../domain/supplier_payment.dart';

class SupplierPaymentsScreen extends ConsumerWidget {
  const SupplierPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(supplierPaymentsProvider);
    final suppliers = ref.watch(suppliersProvider);
    final purchases = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Payments'),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<SupplierPayment>(
                context: context,
                builder: (_) => _SupplierPaymentFormDialog(
                  suppliers: suppliers,
                  purchases: purchases,
                  payments: payments,
                  existing: null,
                ),
              );
              if (created != null) {
                await ref
                    .read(supplierPaymentRepositoryProvider)
                    .upsert(created);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: ListView.separated(
            itemCount: payments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              final supplierName = suppliers.isEmpty
                  ? 'Unknown'
                  : suppliers
                      .firstWhere(
                        (item) => item.id == payment.supplierId,
                        orElse: () => suppliers.first,
                      )
                      .name;
              return ListTile(
                title: Text(supplierName),
                subtitle: Text(formatDate(payment.date)),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final updated = await showDialog<SupplierPayment>(
                        context: context,
                        builder: (_) => _SupplierPaymentFormDialog(
                          suppliers: suppliers,
                          purchases: purchases,
                          payments: payments,
                          existing: payment,
                        ),
                      );
                      if (updated != null) {
                        await ref
                            .read(supplierPaymentRepositoryProvider)
                            .upsert(updated);
                      }
                    }
                    if (value == 'delete') {
                      final confirm = await _confirmDelete(context);
                      if (confirm) {
                        await ref
                            .read(supplierPaymentRepositoryProvider)
                            .deleteById(payment.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SupplierPaymentFormDialog extends StatefulWidget {
  const _SupplierPaymentFormDialog({
    required this.suppliers,
    required this.purchases,
    required this.payments,
    required this.existing,
  });

  final List<Supplier> suppliers;
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;
  final SupplierPayment? existing;

  @override
  State<_SupplierPaymentFormDialog> createState() =>
      _SupplierPaymentFormDialogState();
}

class _SupplierPaymentFormDialogState
    extends State<_SupplierPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _supplierId;
  String? _purchaseId;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _supplierId = existing.supplierId;
      _purchaseId = existing.purchaseId;
      _date = existing.date;
      _amount.text = existing.amount.toString();
      _note.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double _balanceForSupplier(String supplierId) {
    final purchases = widget.purchases
        .where((purchase) => purchase.supplierId == supplierId)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final payments = widget.payments
        .where((payment) => payment.supplierId == supplierId)
        .fold(0.0, (sum, item) => sum + item.amount);
    return purchases - payments;
  }

  @override
  Widget build(BuildContext context) {
    final balance =
        _supplierId == null ? 0.0 : _balanceForSupplier(_supplierId!);

    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Add Supplier Payment'
          : 'Edit Supplier Payment'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _supplierId,
                  items: [
                    for (final supplier in widget.suppliers)
                      DropdownMenuItem(
                        value: supplier.id,
                        child: Text(supplier.name),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  onChanged: (value) => setState(() {
                    _supplierId = value;
                    _purchaseId = null;
                  }),
                  validator: (value) =>
                      value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _purchaseId,
                  items: [
                    for (final purchase in widget.purchases
                        .where((purchase) => purchase.supplierId == _supplierId))
                      DropdownMenuItem(
                        value: purchase.id,
                        child: Text(
                          '${formatDate(purchase.date)} • ${formatMoney(purchase.totalPrice)}',
                        ),
                      )
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Purchase (optional)'),
                  onChanged: (value) => setState(() => _purchaseId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Amount must be > 0';
                    }
                    if (_supplierId != null && parsed > balance) {
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
                  title: const Text('Current Balance'),
                  trailing: Text(formatMoney(balance)),
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
                id: widget.existing?.id ?? '',
                supplierId: _supplierId!,
                purchaseId: _purchaseId,
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
      title: const Text('Delete supplier payment?'),
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
