import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../data/supplier_providers.dart';
import '../domain/supplier.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final purchases = ref.watch(purchasesProvider);
    final payments = ref.watch(supplierPaymentsProvider);

    final filtered = suppliers.where((supplier) {
      final q = _query.toLowerCase();
      return supplier.name.toLowerCase().contains(q) ||
          supplier.phone.toLowerCase().contains(q) ||
          supplier.province.toLowerCase().contains(q) ||
          supplier.district.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<Supplier>(
                context: context,
                builder: (context) => const _SupplierFormDialog(),
              );
              if (created != null) {
                await ref.read(supplierRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, phone, province, district',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final supplier = filtered[index];
                    final supplierPurchases = purchases
                        .where((purchase) =>
                            purchase.supplierId == supplier.id)
                        .fold(0.0, (sum, item) => sum + item.totalPrice);
                    final supplierPayments = payments
                        .where((payment) =>
                            payment.supplierId == supplier.id)
                        .fold(0.0, (sum, item) => sum + item.amount);
                    final balance = supplierPurchases - supplierPayments;

                    return ListTile(
                      title: Text(supplier.name),
                      subtitle: Text(
                        '${supplier.phone} • ${supplier.province}, ${supplier.district}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final updated = await showDialog<Supplier>(
                              context: context,
                              builder: (context) => _SupplierFormDialog(
                                existing: supplier,
                              ),
                            );
                            if (updated != null) {
                              await ref
                                  .read(supplierRepositoryProvider)
                                  .upsert(updated);
                            }
                          }
                          if (value == 'delete') {
                            final confirm = await _confirmDelete(context);
                            if (confirm) {
                              await ref
                                  .read(supplierRepositoryProvider)
                                  .deleteById(supplier.id);
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Text('Balance: ${formatMoney(balance)}'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({this.existing});

  final Supplier? existing;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _province;
  late final TextEditingController _district;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _province = TextEditingController(text: widget.existing?.province ?? '');
    _district = TextEditingController(text: widget.existing?.district ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _province.dispose();
    _district.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Supplier' : 'Edit Supplier'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _province,
                  decoration: const InputDecoration(labelText: 'Province'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _district,
                  decoration: const InputDecoration(labelText: 'District'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address'),
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
            final updated = Supplier(
              id: widget.existing?.id ?? '',
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              province: _province.text.trim(),
              district: _district.text.trim(),
              address: _address.text.trim().isEmpty
                  ? null
                  : _address.text.trim(),
            );
            Navigator.pop(context, updated);
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
