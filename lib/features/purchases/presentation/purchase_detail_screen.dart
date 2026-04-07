import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/theme/app_colors.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../../supplier_payments/data/supplier_payment_repository.dart';
import '../../supplier_payments/domain/supplier_payment.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../units/data/unit_providers.dart';
import '../data/purchase_repository.dart';
import '../data/purchase_providers.dart';
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

    final supplier = suppliers.isEmpty
        ? null
        : suppliers.firstWhere(
            (item) => item.id == purchase.supplierId,
            orElse: () => suppliers.first,
          );
    final supplierName = supplier?.name ?? 'Unknown';
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
    final lastPaymentDate =
        related.isEmpty ? null : related.first.date;

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
          FutureBuilder<bool>(
            future: ref.read(purchaseRepositoryProvider).canEdit(purchase.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final updated = await showDialog<Purchase>(
                    context: context,
                    builder: (_) => _EditPurchaseDialog(purchase: purchase),
                  );
                  if (updated != null) {
                    await ref.read(purchaseRepositoryProvider).upsert(updated);
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
              );
            },
          ),
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
          FutureBuilder<bool>(
            future: ref.read(purchaseRepositoryProvider).canEdit(purchase.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final confirm = await _confirmDelete(context);
                  if (confirm) {
                    await ref
                        .read(purchaseRepositoryProvider)
                        .deleteById(purchase.id);
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
            title: 'Purchase Overview',
            subtitle: 'Supplier and purchase details',
            icon: Icons.shopping_cart_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Supplier Info',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  InfoRow(label: 'Supplier', value: supplierName),
                  if (supplier != null) ...[
                    InfoRow(label: 'Phone', value: supplier.phone),
                    InfoRow(
                      label: 'Location',
                      value:
                          '${supplier.province}, ${supplier.district}',
                    ),
                    if (supplier.address != null &&
                        supplier.address!.isNotEmpty)
                      InfoRow(label: 'Address', value: supplier.address!),
                  ],
                  const Divider(height: 24),
                  Text('Purchase Details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  InfoRow(label: 'Date', value: formatDate(purchase.date)),
                  InfoRow(
                    label: 'Quantity',
                    value: '${purchase.quantityValue} $unitName',
                  ),
                  InfoRow(
                    label: 'Price per unit',
                    value: formatMoney(purchase.pricePerUnit),
                  ),
                  InfoRow(
                    label: 'Total',
                    value: formatMoney(purchase.totalPrice),
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
                  InfoRow(
                    label: 'Payments Count',
                    value: related.length.toString(),
                  ),
                  if (lastPaymentDate != null)
                    InfoRow(
                      label: 'Last Payment',
                      value: formatDate(lastPaymentDate),
                    ),
                  if (purchase.note != null && purchase.note!.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('Note',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(purchase.note!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Payments',
            subtitle: 'Payments made for this purchase',
            icon: Icons.payments_outlined,
          ),
          if (related.isEmpty)
            const EmptyStateCard(
              title: 'No payments yet',
              subtitle: 'Add a payment to close this purchase.',
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

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete purchase?'),
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

class _EditPurchaseDialog extends StatefulWidget {
  const _EditPurchaseDialog({required this.purchase});

  final Purchase purchase;

  @override
  State<_EditPurchaseDialog> createState() => _EditPurchaseDialogState();
}

class _EditPurchaseDialogState extends State<_EditPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.purchase.date;
    _quantity.text = widget.purchase.quantityValue.toString();
    _price.text = widget.purchase.pricePerUnit.toString();
    _note.text = widget.purchase.note ?? '';
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
      title: const Text('Edit Purchase'),
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
              widget.purchase.copyWith(
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
