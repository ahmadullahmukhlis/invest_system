import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../data/user_providers.dart';
import '../../../ui/responsive.dart';
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
    final userRepo = ref.watch(userRepositoryProvider);
    final suppliers = ref.watch(suppliersProvider);
    final purchases = ref.watch(purchasesProvider);
    final payments = ref.watch(supplierPaymentsProvider);
    final canCreateSupplier = canCreate(userRepo, 'suppliers');
    final canEditSupplier = canEdit(userRepo, 'suppliers');
    final canDeleteSupplier = canRemove(userRepo, 'suppliers');

    final filtered = suppliers.where((supplier) {
      final q = _query.toLowerCase();
      return supplier.name.toLowerCase().contains(q) ||
          supplier.phone.toLowerCase().contains(q) ||
          supplier.province.toLowerCase().contains(q) ||
          supplier.district.toLowerCase().contains(q);
    }).toList();

    final isDesktop = Responsive.isDesktop(context);

    return DesktopScaffold(
      title: 'Suppliers',
      actions: [
        if (canCreateSupplier)
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
            tooltip: 'Add supplier',
          ),
      ],
      body: RefreshWrapper(
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
            else if (isDesktop)
              DesktopTable(
                columns: const [
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Balance')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final supplier in filtered)
                    _buildSupplierRow(
                      context,
                      ref,
                      supplier: supplier,
                      purchases: purchases,
                      payments: payments,
                      canEditSupplier: canEditSupplier,
                      canDeleteSupplier: canDeleteSupplier,
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final supplier in filtered) ...[
                    _buildSupplierCard(
                      context,
                      ref,
                      supplier: supplier,
                      purchases: purchases,
                      payments: payments,
                      canEditSupplier: canEditSupplier,
                      canDeleteSupplier: canDeleteSupplier,
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

  DataRow _buildSupplierRow(
    BuildContext context,
    WidgetRef ref, {
    required Supplier supplier,
    required List purchases,
    required List payments,
    required bool canEditSupplier,
    required bool canDeleteSupplier,
  }) {
    final supplierPurchases = purchases
        .where((purchase) => purchase.supplierId == supplier.id)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final supplierPayments = payments
        .where((payment) => payment.supplierId == supplier.id)
        .fold(0.0, (sum, item) => sum + item.amount);
    final balance = supplierPurchases - supplierPayments;

    return DataRow(
      cells: [
        DataCell(Text(supplier.name)),
        DataCell(Text(supplier.phone)),
        DataCell(Text('${supplier.province}, ${supplier.district}')),
        DataCell(Text(formatMoney(balance))),
        DataCell(
          Align(
            alignment: Alignment.centerLeft,
            child: _buildActionsMenu(
              context,
              ref,
              supplier,
              canEditSupplier: canEditSupplier,
              canDeleteSupplier: canDeleteSupplier,
            ),
          ),
        ),
      ],
      onSelectChanged: (_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupplierLedgerScreen(supplier: supplier),
          ),
        );
      },
    );
  }

  Widget _buildSupplierCard(
    BuildContext context,
    WidgetRef ref, {
    required Supplier supplier,
    required List purchases,
    required List payments,
    required bool canEditSupplier,
    required bool canDeleteSupplier,
  }) {
    final supplierPurchases = purchases
        .where((purchase) => purchase.supplierId == supplier.id)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final supplierPayments = payments
        .where((payment) => payment.supplierId == supplier.id)
        .fold(0.0, (sum, item) => sum + item.amount);
    final balance = supplierPurchases - supplierPayments;

    return Card(
      child: ListTile(
        title: Text(supplier.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${supplier.phone} • ${supplier.province}, ${supplier.district}',
            ),
            Text('Balance: ${formatMoney(balance)}'),
          ],
        ),
        trailing: _buildActionsMenu(
          context,
          ref,
          supplier,
          canEditSupplier: canEditSupplier,
          canDeleteSupplier: canDeleteSupplier,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SupplierLedgerScreen(supplier: supplier),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionsMenu(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier, {
    required bool canEditSupplier,
    required bool canDeleteSupplier,
  }) {
    if (!canEditSupplier && !canDeleteSupplier) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      onSelected: (value) async {
        final canEdit = await ref
            .read(supplierRepositoryProvider)
            .canEdit(supplier.id);
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
          final updated = await showDialog<Supplier>(
            context: context,
            builder: (context) => SupplierFormDialog(existing: supplier),
          );
          if (updated != null) {
            await ref.read(supplierRepositoryProvider).upsert(updated);
          }
        }
        if (value == 'delete') {
          final confirm = await _confirmDelete(context);
          if (confirm) {
            await ref.read(supplierRepositoryProvider).deleteById(supplier.id);
          }
        }
      },
      itemBuilder: (_) => [
        if (canEditSupplier)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (canDeleteSupplier)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
