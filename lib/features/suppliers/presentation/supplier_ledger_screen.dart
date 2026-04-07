import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../purchases/domain/purchase.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../../supplier_payments/domain/supplier_payment.dart';
import '../../units/data/unit_providers.dart';
import '../../units/domain/unit.dart';
import '../data/supplier_repository.dart';
import '../data/supplier_providers.dart';
import '../domain/supplier.dart';
import 'supplier_form_dialog.dart';

class SupplierLedgerScreen extends ConsumerStatefulWidget {
  const SupplierLedgerScreen({super.key, required this.supplier});

  final Supplier supplier;

  @override
  ConsumerState<SupplierLedgerScreen> createState() =>
      _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends ConsumerState<SupplierLedgerScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider).where((purchase) {
      return purchase.supplierId == widget.supplier.id;
    }).toList();
    final payments = ref.watch(supplierPaymentsProvider).where((payment) {
      return payment.supplierId == widget.supplier.id;
    }).toList();
    final units = ref.watch(unitsProvider);

    final entries = <_LedgerEntry>[];
    for (final purchase in purchases) {
      entries.add(_LedgerEntry(
        date: purchase.date,
        type: 'Purchase',
        amount: purchase.totalPrice,
        note: purchase.note,
        isDebit: true,
      ));
    }
    for (final payment in payments) {
      entries.add(_LedgerEntry(
        date: payment.date,
        type: 'Payment',
        amount: payment.amount,
        note: payment.note,
        isDebit: false,
      ));
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    final filtered = _range == null
        ? entries
        : entries.where((entry) {
            return entry.date.isAfter(_range!.start
                    .subtract(const Duration(days: 1))) &&
                entry.date.isBefore(
                    _range!.end.add(const Duration(days: 1)));
          }).toList();

    double running = 0;
    final rows = filtered.map((entry) {
      running += entry.isDebit ? entry.amount : -entry.amount;
      return entry.copyWith(runningBalance: running);
    }).toList();

    final totalPurchases =
        purchases.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalPayments =
        payments.fold(0.0, (sum, item) => sum + item.amount);
    final balance = totalPurchases - totalPayments;
    final lastPurchaseDate = purchases.isEmpty
        ? null
        : (purchases..sort((a, b) => b.date.compareTo(a.date))).first.date;
    final lastPaymentDate = payments.isEmpty
        ? null
        : (payments..sort((a, b) => b.date.compareTo(a.date))).first.date;

    return Scaffold(
      appBar: AppBar(
        title: Text('Supplier • ${widget.supplier.name}'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          FutureBuilder<bool>(
            future:
                ref.read(supplierRepositoryProvider).canEdit(widget.supplier.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final updated = await showDialog<Supplier>(
                    context: context,
                    builder: (context) => SupplierFormDialog(
                      existing: widget.supplier,
                    ),
                  );
                  if (updated != null) {
                    await ref
                        .read(supplierRepositoryProvider)
                        .upsert(updated);
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
              );
            },
          ),
          FutureBuilder<bool>(
            future:
                ref.read(supplierRepositoryProvider).canEdit(widget.supplier.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final confirm = await _confirmDelete(context);
                  if (confirm) {
                    await ref
                        .read(supplierRepositoryProvider)
                        .deleteById(widget.supplier.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
              );
            },
          ),
          IconButton(
            onPressed: () async {
              final created = await showDialog<Purchase>(
                context: context,
                builder: (_) => _PurchaseForSupplierDialog(
                  supplierId: widget.supplier.id,
                  units: units.where((unit) => unit.isActive).toList(),
                ),
              );
              if (created != null) {
                await ref.read(purchaseRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_shopping_cart_outlined),
            tooltip: 'Add Purchase',
          ),
          IconButton(
            onPressed: () async {
              final created = await showDialog<SupplierPayment>(
                context: context,
                builder: (_) => _PaymentForSupplierDialog(
                  supplierId: widget.supplier.id,
                  purchases: purchases,
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
          TextButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _range = picked);
              }
            },
            icon: const Icon(Icons.date_range_outlined),
            label: const Text('Filter'),
          ),
          if (_range != null)
            IconButton(
              onPressed: () => setState(() => _range = null),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Supplier Info',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.supplier.name}'),
                    Text('Phone: ${widget.supplier.phone}'),
                    Text(
                        'Location: ${widget.supplier.province}, ${widget.supplier.district}'),
                    if (widget.supplier.address != null &&
                        widget.supplier.address!.isNotEmpty)
                      Text('Address: ${widget.supplier.address}'),
                    const Divider(),
                    Text('Total Purchases: ${formatMoney(totalPurchases)}'),
                    Text('Total Payments: ${formatMoney(totalPayments)}'),
                    Text('Balance: ${formatMoney(balance)}'),
                    if (lastPurchaseDate != null)
                      Text('Last Purchase: ${formatDate(lastPurchaseDate)}'),
                    if (lastPaymentDate != null)
                      Text('Last Payment: ${formatDate(lastPaymentDate)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = rows[index];
                  return ListTile(
                    leading: Icon(
                      entry.isDebit
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    title: Text('${entry.type} • ${formatDate(entry.date)}'),
                    subtitle: Text(entry.note ?? 'No note'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(formatMoney(entry.amount)),
                        Text('Balance: ${formatMoney(entry.runningBalance)}'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerEntry {
  const _LedgerEntry({
    required this.date,
    required this.type,
    required this.amount,
    required this.isDebit,
    this.note,
    this.runningBalance = 0,
  });

  final DateTime date;
  final String type;
  final double amount;
  final bool isDebit;
  final String? note;
  final double runningBalance;

  _LedgerEntry copyWith({double? runningBalance}) {
    return _LedgerEntry(
      date: date,
      type: type,
      amount: amount,
      isDebit: isDebit,
      note: note,
      runningBalance: runningBalance ?? this.runningBalance,
    );
  }
}

class _PurchaseForSupplierDialog extends StatefulWidget {
  const _PurchaseForSupplierDialog({
    required this.supplierId,
    required this.units,
  });

  final String supplierId;
  final List<Unit> units;

  @override
  State<_PurchaseForSupplierDialog> createState() =>
      _PurchaseForSupplierDialogState();
}

class _PurchaseForSupplierDialogState extends State<_PurchaseForSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _unitId;
  DateTime _date = DateTime.now();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  double _totalPrice = 0;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  void _recalculate() {
    final quantity = double.tryParse(_quantity.text) ?? 0;
    final price = double.tryParse(_price.text) ?? 0;
    setState(() => _totalPrice = quantity * price);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Purchase'),
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
                  onChanged: (_) => _recalculate(),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Quantity must be > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _unitId,
                  items: [
                    for (final unit in widget.units)
                      DropdownMenuItem(
                        value: unit.id,
                        child: Text(unit.name),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'Unit'),
                  onChanged: (value) => setState(() => _unitId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price per unit'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalculate(),
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
                  title: const Text('Total'),
                  trailing: Text(formatMoney(_totalPrice)),
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
              Purchase(
                id: '',
                supplierId: widget.supplierId,
                date: _date,
                quantityValue: quantity,
                unitId: _unitId!,
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

class _PaymentForSupplierDialog extends StatefulWidget {
  const _PaymentForSupplierDialog({
    required this.supplierId,
    required this.purchases,
  });

  final String supplierId;
  final List<Purchase> purchases;

  @override
  State<_PaymentForSupplierDialog> createState() =>
      _PaymentForSupplierDialogState();
}

class _PaymentForSupplierDialogState extends State<_PaymentForSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _purchaseId;
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
                DropdownButtonFormField<String>(
                  value: _purchaseId,
                  items: [
                    for (final purchase in widget.purchases)
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
      title: const Text('Delete supplier?'),
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
