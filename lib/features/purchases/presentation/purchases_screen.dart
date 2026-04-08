import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../ui/responsive.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../suppliers/domain/supplier.dart';
import '../../units/data/unit_providers.dart';
import '../../units/domain/unit.dart';
import '../data/purchase_providers.dart';
import '../domain/purchase.dart';
import 'purchase_detail_screen.dart';
import '../../receipts/presentation/purchase_receipt_screen.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider);
    final suppliers = ref.watch(suppliersProvider);
    final units = ref.watch(unitsProvider);

    final isDesktop = Responsive.isDesktop(context);

    return DesktopScaffold(
      title: 'Purchases',
      actions: [
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
          tooltip: 'Add purchase',
        ),
      ],
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Purchases',
              subtitle: '${purchases.length} records',
              icon: Icons.shopping_cart_outlined,
            ),
            if (purchases.isEmpty)
              const EmptyStateCard(
                title: 'No purchases yet',
                subtitle: 'Add a purchase to track inventory costs.',
                icon: Icons.shopping_cart_outlined,
              )
            else if (isDesktop)
              DesktopTable(
                minWidth: 1100,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Note')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Unit Price')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final purchase in purchases)
                    _buildPurchaseRow(
                      context,
                      ref,
                      purchase: purchase,
                      suppliers: suppliers,
                      units: units,
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final purchase in purchases) ...[
                    _buildPurchaseCard(
                      context,
                      ref,
                      purchase: purchase,
                      suppliers: suppliers,
                      units: units,
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

DataRow _buildPurchaseRow(
  BuildContext context,
  WidgetRef ref, {
  required Purchase purchase,
  required List<Supplier> suppliers,
  required List<Unit> units,
}) {
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

  return DataRow(
    cells: [
      DataCell(Text(formatDate(purchase.date))),
      DataCell(Text(supplierName)),
      DataCell(Text(purchase.note?.isNotEmpty == true ? purchase.note! : '-')),
      DataCell(Text('${purchase.quantityValue} $unitName')),
      DataCell(Text(formatMoney(purchase.pricePerUnit))),
      DataCell(Text(formatMoney(purchase.totalPrice))),
      DataCell(
        Align(
          alignment: Alignment.centerLeft,
          child:
              _buildPurchaseActionsMenu(context, ref, purchase, suppliers, units),
        ),
      ),
    ],
    onSelectChanged: (_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PurchaseDetailScreen(purchase: purchase),
        ),
      );
    },
  );
}

Widget _buildPurchaseCard(
  BuildContext context,
  WidgetRef ref, {
  required Purchase purchase,
  required List<Supplier> suppliers,
  required List<Unit> units,
}) {
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

  return Card(
    child: ListTile(
      title: Text(supplierName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatDate(purchase.date)} • ${purchase.quantityValue} $unitName @ ${formatMoney(purchase.pricePerUnit)}',
          ),
          Text('Total: ${formatMoney(purchase.totalPrice)}'),
        ],
      ),
      trailing:
          _buildPurchaseActionsMenu(context, ref, purchase, suppliers, units),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PurchaseDetailScreen(purchase: purchase),
          ),
        );
      },
    ),
  );
}

Widget _buildPurchaseActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Purchase purchase,
  List<Supplier> suppliers,
  List<Unit> units,
) {
  return PopupMenuButton<String>(
    onSelected: (value) async {
      if (value == 'details') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PurchaseDetailScreen(purchase: purchase),
          ),
        );
        return;
      }
      if (value == 'receipt') {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PurchaseReceiptScreen(purchase: purchase),
            ),
          );
        }
        return;
      }
      final canEdit =
          await ref.read(purchaseRepositoryProvider).canEdit(purchase.id);
      if (!canEdit) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only edit your own records.'),
            ),
          );
        }
        return;
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
          await ref.read(purchaseRepositoryProvider).upsert(updated);
        }
      }
      if (value == 'delete') {
        final confirm = await _confirmDelete(context);
        if (confirm) {
          await ref.read(purchaseRepositoryProvider).deleteById(purchase.id);
        }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'details', child: Text('Details')),
      PopupMenuItem(value: 'receipt', child: Text('Receipt')),
      PopupMenuItem(value: 'edit', child: Text('Edit')),
      PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );
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
