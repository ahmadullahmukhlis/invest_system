import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../ui/responsive.dart';
import '../../customers/data/customer_providers.dart';
import '../../customers/domain/customer.dart';
import '../../units/data/unit_providers.dart';
import '../../units/domain/unit.dart';
import '../data/sale_providers.dart';
import '../domain/sale.dart';
import 'sale_detail_screen.dart';
import '../../../data/user_providers.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final sales = ref.watch(salesProvider);
    final customers = ref.watch(customersProvider);
    final units = ref.watch(unitsProvider);
    final canCreateSale = canCreate(userRepo, 'sales');
    final canEditSale = canEdit(userRepo, 'sales');
    final canDeleteSale = canRemove(userRepo, 'sales');

    final isDesktop = Responsive.isDesktop(context);

    return DesktopScaffold(
      title: 'Sales',
      actions: [
        if (canCreateSale)
          IconButton(
            onPressed: () async {
              final created = await showDialog<Sale>(
                context: context,
                builder: (_) => _SaleFormDialog(
                  customers: customers,
                  units: units.where((unit) => unit.isActive).toList(),
                  existing: null,
                ),
              );
              if (created != null) {
                await ref.read(saleRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add sale',
          ),
      ],
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Sales',
              subtitle: '${sales.length} records',
              icon: Icons.receipt_long_outlined,
            ),
            if (sales.isEmpty)
              const EmptyStateCard(
                title: 'No sales yet',
                subtitle: 'Create a sale to start tracking revenue.',
                icon: Icons.receipt_long_outlined,
              )
            else if (isDesktop)
              DesktopTable(
                minWidth: 1100,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Note')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Unit Price')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final sale in sales)
                    _buildSaleRow(
                      context,
                      ref,
                      sale: sale,
                      customers: customers,
                      units: units,
                      canEditSale: canEditSale,
                      canDeleteSale: canDeleteSale,
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final sale in sales) ...[
                    _buildSaleCard(
                      context,
                      ref,
                      sale: sale,
                      customers: customers,
                      units: units,
                      canEditSale: canEditSale,
                      canDeleteSale: canDeleteSale,
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

DataRow _buildSaleRow(
  BuildContext context,
  WidgetRef ref, {
  required Sale sale,
  required List<Customer> customers,
  required List<Unit> units,
  required bool canEditSale,
  required bool canDeleteSale,
}) {
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

  return DataRow(
    cells: [
      DataCell(Text(formatDate(sale.date))),
      DataCell(Text(customerName)),
      DataCell(Text(sale.note?.isNotEmpty == true ? sale.note! : '-')),
      DataCell(Text('${sale.quantityValue} $unitName')),
      DataCell(Text(formatMoney(sale.pricePerUnit))),
      DataCell(Text(formatMoney(sale.totalPrice))),
      DataCell(
        Align(
          alignment: Alignment.centerLeft,
          child: _buildSaleActionsMenu(
            context,
            ref,
            sale,
            customers,
            units,
            canEditSale: canEditSale,
            canDeleteSale: canDeleteSale,
          ),
        ),
      ),
    ],
    onSelectChanged: (_) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)));
    },
  );
}

Widget _buildSaleCard(
  BuildContext context,
  WidgetRef ref, {
  required Sale sale,
  required List<Customer> customers,
  required List<Unit> units,
  required bool canEditSale,
  required bool canDeleteSale,
}) {
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

  return Card(
    child: ListTile(
      title: Text(customerName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatDate(sale.date)} • ${sale.quantityValue} $unitName @ ${formatMoney(sale.pricePerUnit)}',
          ),
          Text('Total: ${formatMoney(sale.totalPrice)}'),
        ],
      ),
      trailing: _buildSaleActionsMenu(
        context,
        ref,
        sale,
        customers,
        units,
        canEditSale: canEditSale,
        canDeleteSale: canDeleteSale,
      ),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)));
      },
    ),
  );
}

Widget _buildSaleActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Sale sale,
  List<Customer> customers,
  List<Unit> units, {
  required bool canEditSale,
  required bool canDeleteSale,
}) {
  if (!canEditSale && !canDeleteSale) {
    return const SizedBox.shrink();
  }

  return PopupMenuButton<String>(
    onSelected: (value) async {
      final canEdit = await ref.read(saleRepositoryProvider).canEdit(sale.id);
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
        final updated = await showDialog<Sale>(
          context: context,
          builder: (_) => _SaleFormDialog(
            customers: customers,
            units: units.where((unit) => unit.isActive).toList(),
            existing: sale,
          ),
        );
        if (updated != null) {
          await ref.read(saleRepositoryProvider).upsert(updated);
        }
      }
      if (value == 'delete') {
        final confirm = await _confirmDelete(context);
        if (confirm) {
          await ref.read(saleRepositoryProvider).deleteById(sale.id);
        }
      }
    },
    itemBuilder: (_) => [
      if (canEditSale) const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (canDeleteSale)
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );
}

class _SaleFormDialog extends StatefulWidget {
  const _SaleFormDialog({
    required this.customers,
    required this.units,
    required this.existing,
  });

  final List<Customer> customers;
  final List<Unit> units;
  final Sale? existing;

  @override
  State<_SaleFormDialog> createState() => _SaleFormDialogState();
}

class _SaleFormDialogState extends State<_SaleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _customerId;
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
      _customerId = existing.customerId;
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
      title: Text(widget.existing == null ? 'Add Sale' : 'Edit Sale'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _customerId,
                  items: [
                    for (final customer in widget.customers)
                      DropdownMenuItem(
                        value: customer.id,
                        child: Text(customer.name),
                      ),
                  ],
                  decoration: const InputDecoration(labelText: 'Customer'),
                  onChanged: (value) => setState(() => _customerId = value),
                  validator: (value) => value == null ? 'Required' : null,
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
                      DropdownMenuItem(value: unit.id, child: Text(unit.name)),
                  ],
                  decoration: const InputDecoration(labelText: 'Unit'),
                  onChanged: (value) => setState(() => _unitId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(
                    labelText: 'Price per unit',
                  ),
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
              Sale(
                id: widget.existing?.id ?? '',
                customerId: _customerId!,
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
