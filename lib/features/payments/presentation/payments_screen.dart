import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../customers/data/customer_providers.dart';
import '../../customers/domain/customer.dart';
import '../../sales/data/sale_providers.dart';
import '../../sales/domain/sale.dart';
import '../data/payment_providers.dart';
import '../domain/payment.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsProvider);
    final customers = ref.watch(customersProvider);
    final sales = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments Received'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<Payment>(
                context: context,
                builder: (_) => _PaymentFormDialog(
                  customers: customers,
                  sales: sales,
                  payments: payments,
                  existing: null,
                ),
              );
              if (created != null) {
                await ref.read(paymentRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
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
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    Customer? customer;
                    if (customers.isNotEmpty) {
                      final matches = customers
                          .where((item) => item.id == payment.customerId);
                      customer = matches.isEmpty ? customers.first : matches.first;
                    }
                    final customerName = customer?.name ?? 'Unknown';
                    final customerSales = sales
                        .where((sale) => sale.customerId == payment.customerId)
                        .fold(0.0, (sum, item) => sum + item.totalPrice);
                    final customerPayments = payments
                        .where((p) => p.customerId == payment.customerId)
                        .fold(0.0, (sum, item) => sum + item.amount);
                    final customerBalance = customerSales - customerPayments;
                    Sale? sale;
                    if (payment.saleId != null) {
                      final matches =
                          sales.where((s) => s.id == payment.saleId);
                      sale = matches.isEmpty ? null : matches.first;
                    }
                    return ListTile(
                      title: Text(customerName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatDate(payment.date)} • ${formatMoney(payment.amount)}',
                          ),
                          Text('Total Sales: ${formatMoney(customerSales)}'),
                          Text('Total Payments: ${formatMoney(customerPayments)}'),
                          Text('Remaining Balance: ${formatMoney(customerBalance)}'),
                          if (sale != null)
                            Text(
                              'Sale: ${formatDate(sale.date)} • ${formatMoney(sale.totalPrice)}',
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          final canEdit = await ref
                              .read(paymentRepositoryProvider)
                              .canEdit(payment.id);
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
                            final updated = await showDialog<Payment>(
                              context: context,
                              builder: (_) => _PaymentFormDialog(
                                customers: customers,
                                sales: sales,
                                payments: payments,
                                existing: payment,
                              ),
                            );
                            if (updated != null) {
                              await ref
                                  .read(paymentRepositoryProvider)
                                  .upsert(updated);
                            }
                          }
                          if (value == 'delete') {
                            final confirm = await _confirmDelete(context);
                            if (confirm) {
                              await ref
                                  .read(paymentRepositoryProvider)
                                  .deleteById(payment.id);
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
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

class _PaymentFormDialog extends StatefulWidget {
  const _PaymentFormDialog({
    required this.customers,
    required this.sales,
    required this.payments,
    required this.existing,
  });

  final List<Customer> customers;
  final List<Sale> sales;
  final List<Payment> payments;
  final Payment? existing;

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _customerId;
  String? _saleId;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _customerId = existing.customerId;
      _saleId = existing.saleId;
      _date = existing.date;
      _amount.text = existing.amount.toString();
      _note.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double _balanceForCustomer(String customerId) {
    final sales = widget.sales
        .where((sale) => sale.customerId == customerId)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final payments = widget.payments
        .where((payment) => payment.customerId == customerId)
        .fold(0.0, (sum, item) => sum + item.amount);
    return sales - payments;
  }

  @override
  Widget build(BuildContext context) {
    Customer? selectedCustomer;
    if (_customerId != null) {
      final matches =
          widget.customers.where((customer) => customer.id == _customerId);
      selectedCustomer = matches.isEmpty ? null : matches.first;
    }
    final customerSales = _customerId == null
        ? const <Sale>[]
        : widget.sales
            .where((sale) => sale.customerId == _customerId)
            .toList();
    final customerPayments = _customerId == null
        ? const <Payment>[]
        : widget.payments
            .where((payment) => payment.customerId == _customerId)
            .toList();
    final paidBySale = <String, double>{};
    for (final payment in customerPayments) {
      final saleId = payment.saleId;
      if (saleId == null) continue;
      paidBySale.update(
        saleId,
        (value) => value + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    final saleById = <String, Sale>{
      for (final sale in customerSales) sale.id: sale,
    };
    final totalSales = customerSales.fold<double>(
        0.0, (sum, item) => sum + item.totalPrice);
    final totalPayments = customerPayments.fold<double>(
        0.0, (sum, item) => sum + item.amount);
    final balance = totalSales - totalPayments;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Payment' : 'Edit Payment'),
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
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'Customer'),
                  onChanged: (value) => setState(() {
                    _customerId = value;
                    _saleId = null;
                  }),
                  validator: (value) =>
                      value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (selectedCustomer != null)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedCustomer.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text('Phone: ${selectedCustomer.phone}'),
                              Text('Province: ${selectedCustomer.province}'),
                              Text('District: ${selectedCustomer.district}'),
                              if ((selectedCustomer.address ?? '').isNotEmpty)
                                Text('Address: ${selectedCustomer.address}'),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Sales'),
                              Text(formatMoney(totalSales)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Payments'),
                              Text(formatMoney(totalPayments)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Current Balance'),
                              Text(formatMoney(balance)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (selectedCustomer != null) const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _saleId,
                  items: [
                    for (final sale in widget.sales
                        .where((sale) => sale.customerId == _customerId))
                      DropdownMenuItem(
                        value: sale.id,
                        child: Text(
                          '${formatDate(sale.date)} • ${formatMoney(sale.totalPrice)}',
                        ),
                      )
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Sale (optional)'),
                  onChanged: (value) => setState(() => _saleId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Amount must be > 0';
                    }
                    if (_customerId != null && parsed > balance) {
                      return 'Payment exceeds balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (selectedCustomer != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Customer Sales'),
                    subtitle: Text('${customerSales.length} sales'),
                    children: [
                      for (final sale in customerSales)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${formatDate(sale.date)} • ${formatMoney(sale.totalPrice)}',
                          ),
                          subtitle: Text(
                            'Paid: ${formatMoney(paidBySale[sale.id] ?? 0.0)} • Remaining: ${formatMoney(sale.totalPrice - (paidBySale[sale.id] ?? 0.0))}',
                          ),
                        ),
                    ],
                  ),
                if (selectedCustomer != null) const SizedBox(height: 8),
                if (selectedCustomer != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Customer Payments'),
                    subtitle: Text('${customerPayments.length} payments'),
                    children: [
                      for (final payment in customerPayments)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${formatDate(payment.date)} • ${formatMoney(payment.amount)}',
                          ),
                          subtitle: Text(
                            payment.saleId == null
                                ? 'Unlinked payment'
                                : 'Sale: ${formatDate(saleById[payment.saleId!]?.date ?? payment.date)}',
                          ),
                        ),
                    ],
                  ),
                if (selectedCustomer != null) const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remaining Balance'),
                  trailing: Text(
                    formatMoney(
                      balance -
                          (double.tryParse(_amount.text.trim()) ?? 0.0),
                    ),
                  ),
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
            Navigator.pop(
              context,
              Payment(
                id: widget.existing?.id ?? '',
                customerId: _customerId!,
                saleId: _saleId,
                date: _date,
                amount: double.parse(_amount.text),
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
      title: const Text('Delete payment?'),
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
