import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/data/geo_providers.dart';
import '../../../core/data/geo_data.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../data/supplier_providers.dart';
import '../domain/supplier.dart';
import 'supplier_ledger_screen.dart';

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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
      drawer: const AppDrawer(),
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
                          if (value == 'details') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SupplierLedgerScreen(
                                  supplier: supplier,
                                ),
                              ),
                            );
                          }
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
                          const PopupMenuItem(
                            value: 'details',
                            child: Text('Details'),
                          ),
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SupplierLedgerScreen(
                              supplier: supplier,
                            ),
                          ),
                        );
                      },
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

class _SupplierFormDialog extends ConsumerStatefulWidget {
  const _SupplierFormDialog({this.existing});

  final Supplier? existing;

  @override
  ConsumerState<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  String? _province;
  String? _district;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _province = widget.existing?.province;
    _district = widget.existing?.district;
    _address = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provinceAsync = ref.watch(provinceDataProvider);
    final provinces = provinceAsync.value ?? const [];
    final selectedProvince = provinces.firstWhere(
      (item) => item.name == _province,
      orElse: () =>
          provinces.isNotEmpty ? provinces.first : _emptyProvince,
    );
    final districtOptions = _province == null
        ? const <String>[]
        : selectedProvince.districts;

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
                DropdownButtonFormField<String>(
                  value: _province,
                  items: [
                    for (final item in provinces)
                      DropdownMenuItem(
                        value: item.name,
                        child: Text(item.name),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'Province'),
                  onChanged: (value) {
                    setState(() {
                      _province = value;
                      _district = null;
                    });
                  },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _district,
                  items: [
                    for (final item in districtOptions)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'District'),
                  onChanged: (value) => setState(() => _district = value),
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
              province: _province ?? '',
              district: _district ?? '',
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

const _emptyProvince = ProvinceData(name: '', districts: []);

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
