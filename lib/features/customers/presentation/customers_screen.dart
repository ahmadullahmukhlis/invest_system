import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
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
                builder: (context) => const CustomerFormDialog(),
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
              else
                Column(
                  children: [
                    for (final customer in filtered) ...[
                      Builder(
                        builder: (context) {
                          final customerSales = sales
                              .where((sale) => sale.customerId == customer.id)
                              .fold(0.0, (sum, item) => sum + item.totalPrice);
                          final customerPayments = payments
                              .where((payment) =>
                                  payment.customerId == customer.id)
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
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'details') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerLedgerScreen(
                                          customer: customer,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final canEdit = await ref
                                      .read(customerRepositoryProvider)
                                      .canEdit(customer.id);
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
                                    final updated = await showDialog<Customer>(
                                      context: context,
                                      builder: (context) => CustomerFormDialog(
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
                                    builder: (_) => CustomerLedgerScreen(
                                      customer: customer,
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
