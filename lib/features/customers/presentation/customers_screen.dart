import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/data/geo_providers.dart';
import '../../../core/data/geo_data.dart';
import '../../payments/data/payment_providers.dart';
import '../../sales/data/sale_providers.dart';
import '../data/customer_providers.dart';
import '../domain/customer.dart';
import 'customer_ledger_screen.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final sales = ref.watch(salesProvider);
    final payments = ref.watch(paymentsProvider);

    final filtered = customers.where((customer) {
      final q = _query.toLowerCase();
      return customer.name.toLowerCase().contains(q) ||
          customer.phone.toLowerCase().contains(q) ||
          customer.province.toLowerCase().contains(q) ||
          customer.district.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<Customer>(
                context: context,
                builder: (context) => const _CustomerFormDialog(),
              );
              if (created != null) {
                await ref.read(customerRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
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
                    final customer = filtered[index];
                    final customerSales = sales
                        .where((sale) => sale.customerId == customer.id)
                        .fold(0.0, (sum, item) => sum + item.totalPrice);
                    final customerPayments = payments
                        .where((payment) => payment.customerId == customer.id)
                        .fold(0.0, (sum, item) => sum + item.amount);
                    final balance = customerSales - customerPayments;

                    return ListTile(
                      title: Text(customer.name),
                      subtitle: Text(
                        '${customer.phone} • ${customer.province}, ${customer.district}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final updated = await showDialog<Customer>(
                              context: context,
                              builder: (context) => _CustomerFormDialog(
                                existing: customer,
                              ),
                            );
                            if (updated != null) {
                              await ref
                                  .read(customerRepositoryProvider)
                                  .upsert(updated);
                            }
                          }
                          if (value == 'delete') {
                            final confirm = await _confirmDelete(context);
                            if (confirm) {
                              await ref
                                  .read(customerRepositoryProvider)
                                  .deleteById(customer.id);
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerLedgerScreen(
                              customer: customer,
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

class _CustomerFormDialog extends ConsumerStatefulWidget {
  const _CustomerFormDialog({this.existing});

  final Customer? existing;

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
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
      title: Text(widget.existing == null ? 'Add Customer' : 'Edit Customer'),
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
            final updated = Customer(
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
      title: const Text('Delete customer?'),
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
