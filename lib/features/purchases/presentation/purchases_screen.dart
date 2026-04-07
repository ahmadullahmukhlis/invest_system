import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../suppliers/domain/supplier.dart';
import '../../units/data/unit_providers.dart';
import '../../units/domain/unit.dart';
import '../data/purchase_providers.dart';
import '../domain/purchase.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider);
    final suppliers = ref.watch(suppliersProvider);
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_open),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          IconButton(
            onPressed: () async {
              final created = await showDialog<Purchase>(
                context: context,
                builder: (_) => _PurchaseFormDialog(
                  suppliers: suppliers,
                  units: units.where((unit) => unit.isActive).toList(),
                  existing: null,
                ),
              );
              if (created != null) {
                await ref.read(purchaseRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: ListView.separated(
            itemCount: purchases.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final purchase = purchases[index];
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
              return ListTile(
                title: Text(supplierName),
                subtitle: Text(
                  '${formatDate(purchase.date)} • ${purchase.quantityValue} $unitName @ ${formatMoney(purchase.pricePerUnit)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'receipt') {
                      await _showReceipt(
                        context,
                        purchase,
                        supplierName,
                        unitName,
                      );
                    }
                    if (value == 'edit') {
                      final updated = await showDialog<Purchase>(
                        context: context,
                        builder: (_) => _PurchaseFormDialog(
                          suppliers: suppliers,
                          units: units.where((unit) => unit.isActive).toList(),
                          existing: purchase,
                        ),
                      );
                      if (updated != null) {
                        await ref
                            .read(purchaseRepositoryProvider)
                            .upsert(updated);
                      }
                    }
                    if (value == 'delete') {
                      final confirm = await _confirmDelete(context);
                      if (confirm) {
                        await ref
                            .read(purchaseRepositoryProvider)
                            .deleteById(purchase.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'receipt', child: Text('Receipt')),
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

class _PurchaseFormDialog extends StatefulWidget {
  const _PurchaseFormDialog({
    required this.suppliers,
    required this.units,
    required this.existing,
  });

  final List<Supplier> suppliers;
  final List<Unit> units;
  final Purchase? existing;

  @override
  State<_PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<_PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _supplierId;
  String? _unitId;
  DateTime _date = DateTime.now();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  double _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _supplierId = existing.supplierId;
      _unitId = existing.unitId;
      _date = existing.date;
      _quantity.text = existing.quantityValue.toString();
      _price.text = existing.pricePerUnit.toString();
      _note.text = existing.note ?? '';
      _totalPrice = existing.totalPrice;
    }
  }

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
      title: Text(widget.existing == null ? 'Add Purchase' : 'Edit Purchase'),
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
                  onChanged: (value) => setState(() => _supplierId = value),
                  validator: (value) =>
                      value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
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
                  validator: (value) =>
                      value == null ? 'Required' : null,
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
                id: widget.existing?.id ?? '',
                supplierId: _supplierId!,
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

Future<void> _showReceipt(
  BuildContext context,
  Purchase purchase,
  String supplierName,
  String unitName,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Purchase Receipt'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier: $supplierName'),
            Text('Date: ${formatDate(purchase.date)}'),
            const Divider(),
            Text('Quantity: ${purchase.quantityValue} $unitName'),
            Text('Price per unit: ${formatMoney(purchase.pricePerUnit)}'),
            Text('Total: ${formatMoney(purchase.totalPrice)}'),
            if (purchase.note != null && purchase.note!.isNotEmpty) ...[
              const Divider(),
              Text('Note: ${purchase.note}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
