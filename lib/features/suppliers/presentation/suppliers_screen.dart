import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import 'supplier_form_dialog.dart';
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
                builder: (context) => const SupplierFormDialog(),
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
        child: RefreshWrapper(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name, phone, province, district',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                            return;
                          }
                          final canEdit = await ref
                              .read(supplierRepositoryProvider)
                              .canEdit(supplier.id);
                          if (!canEdit) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'You can only edit your own records.'),
                                ),
                              );
                            }
                            return;
                          }
                          if (value == 'edit') {
                            final updated = await showDialog<Supplier>(
                              context: context,
                              builder: (context) => SupplierFormDialog(
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
            ],
          ),
        ),
      ),
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
