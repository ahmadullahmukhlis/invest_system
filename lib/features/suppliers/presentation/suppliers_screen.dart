import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
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
              SectionHeader(
                title: 'Suppliers',
                subtitle: '${filtered.length} records',
                icon: Icons.storefront,
              ),
              if (filtered.isEmpty)
                const EmptyStateCard(
                  title: 'No suppliers yet',
                  subtitle: 'Add your first supplier to get started.',
                  icon: Icons.storefront_outlined,
                )
              else
                Column(
                  children: [
                    for (final supplier in filtered) ...[
                      Builder(
                        builder: (context) {
                          final supplierPurchases = purchases
                              .where((purchase) =>
                                  purchase.supplierId == supplier.id)
                              .fold(0.0, (sum, item) => sum + item.totalPrice);
                          final supplierPayments = payments
                              .where((payment) =>
                                  payment.supplierId == supplier.id)
                              .fold(0.0, (sum, item) => sum + item.amount);
                          final balance =
                              supplierPurchases - supplierPayments;
                          return Card(
                            child: ListTile(
                              title: Text(supplier.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${supplier.phone} • ${supplier.province}, ${supplier.district}',
                                  ),
                                  Text(
                                    'Balance: ${formatMoney(balance)}',
                                  ),
                                ],
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
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'details',
                                    child: Text('Details'),
                                  ),
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
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
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
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
