import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../ui/responsive.dart';
import 'customer_form_dialog.dart';
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

    final isDesktop = Responsive.isDesktop(context);

    return DesktopScaffold(
      title: 'Customers',
      actions: [
        IconButton(
          onPressed: () async {
            final created = await showDialog<Customer>(
              context: context,
              builder: (context) => const CustomerFormDialog(),
            );
            if (created != null) {
              await ref.read(customerRepositoryProvider).upsert(created);
            }
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
          tooltip: 'Add customer',
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
              title: 'Customers',
              subtitle: '${filtered.length} records',
              icon: Icons.people_outline,
            ),
            if (filtered.isEmpty)
              const EmptyStateCard(
                title: 'No customers yet',
                subtitle: 'Add your first customer to get started.',
                icon: Icons.person_outline,
              )
            else if (isDesktop)
              DesktopTable(
                columns: const [
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Balance')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final customer in filtered)
                    _buildCustomerRow(
                      context,
                      ref,
                      customer: customer,
                      sales: sales,
                      payments: payments,
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final customer in filtered) ...[
                    _buildCustomerCard(
                      context,
                      ref,
                      customer: customer,
                      sales: sales,
                      payments: payments,
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

  DataRow _buildCustomerRow(
    BuildContext context,
    WidgetRef ref, {
    required Customer customer,
    required List sales,
    required List payments,
  }) {
    final customerSales = sales
        .where((sale) => sale.customerId == customer.id)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final customerPayments = payments
        .where((payment) => payment.customerId == customer.id)
        .fold(0.0, (sum, item) => sum + item.amount);
    final balance = customerSales - customerPayments;

    return DataRow(
      cells: [
        DataCell(Text(customer.name)),
        DataCell(Text(customer.phone)),
        DataCell(Text('${customer.province}, ${customer.district}')),
        DataCell(Text(formatMoney(balance))),
        DataCell(
          Align(
            alignment: Alignment.centerLeft,
            child: _buildActionsMenu(context, ref, customer),
          ),
        ),
      ],
      onSelectChanged: (_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerLedgerScreen(customer: customer),
          ),
        );
      },
    );
  }

  Widget _buildCustomerCard(
    BuildContext context,
    WidgetRef ref, {
    required Customer customer,
    required List sales,
    required List payments,
  }) {
    final customerSales = sales
        .where((sale) => sale.customerId == customer.id)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final customerPayments = payments
        .where((payment) => payment.customerId == customer.id)
        .fold(0.0, (sum, item) => sum + item.amount);
    final balance = customerSales - customerPayments;

    return Card(
      child: ListTile(
        title: Text(customer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${customer.phone} • ${customer.province}, ${customer.district}',
            ),
            Text(
              'Balance: ${formatMoney(balance)}',
            ),
          ],
        ),
        trailing: _buildActionsMenu(context, ref, customer),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerLedgerScreen(customer: customer),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionsMenu(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'details') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerLedgerScreen(customer: customer),
            ),
          );
          return;
        }
        final canEdit =
            await ref.read(customerRepositoryProvider).canEdit(customer.id);
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
          final updated = await showDialog<Customer>(
            context: context,
            builder: (context) => CustomerFormDialog(existing: customer),
          );
          if (updated != null) {
            await ref.read(customerRepositoryProvider).upsert(updated);
          }
        }
        if (value == 'delete') {
          final confirm = await _confirmDelete(context);
          if (confirm) {
            await ref.read(customerRepositoryProvider).deleteById(customer.id);
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
    );
  }
}


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
