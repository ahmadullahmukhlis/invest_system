import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../payments/data/payment_providers.dart';
import 'customer_form_dialog.dart';
import '../data/customer_providers.dart';
import '../../payments/domain/payment.dart';
import '../../sales/data/sale_providers.dart';
import '../../sales/domain/sale.dart';
import '../../units/data/unit_providers.dart';
import '../../units/domain/unit.dart';
import '../domain/customer.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  const CustomerLedgerScreen({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider).where((sale) {
      return sale.customerId == widget.customer.id;
    }).toList();
    final payments = ref.watch(paymentsProvider).where((payment) {
      return payment.customerId == widget.customer.id;
    }).toList();
    final units = ref.watch(unitsProvider);

    final entries = <_LedgerEntry>[];
    for (final sale in sales) {
      entries.add(_LedgerEntry(
        date: sale.date,
        type: 'Sale',
        amount: sale.totalPrice,
        note: sale.note,
        isCredit: true,
      ));
    }
    for (final payment in payments) {
      entries.add(_LedgerEntry(
        date: payment.date,
        type: 'Payment',
        amount: payment.amount,
        note: payment.note,
        isCredit: false,
      ));
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    final filtered = _range == null
        ? entries
        : entries.where((entry) {
            return entry.date.isAfter(_range!.start
                    .subtract(const Duration(days: 1))) &&
                entry.date.isBefore(
                    _range!.end.add(const Duration(days: 1)));
          }).toList();

    double running = 0;
    final rows = filtered.map((entry) {
      running += entry.isCredit ? entry.amount : -entry.amount;
      return entry.copyWith(runningBalance: running);
    }).toList();

    final totalSales =
        sales.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalPayments =
        payments.fold(0.0, (sum, item) => sum + item.amount);
    final balance = totalSales - totalPayments;
    final lastSaleDate =
        sales.isEmpty ? null : (sales..sort((a, b) => b.date.compareTo(a.date))).first.date;
    final lastPaymentDate = payments.isEmpty
        ? null
        : (payments..sort((a, b) => b.date.compareTo(a.date))).first.date;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ledger • ${widget.customer.name}'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          FutureBuilder<bool>(
            future:
                ref.read(customerRepositoryProvider).canEdit(widget.customer.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final updated = await showDialog<Customer>(
                    context: context,
                    builder: (context) => CustomerFormDialog(
                      existing: widget.customer,
                    ),
                  );
                  if (updated != null) {
                    await ref.read(customerRepositoryProvider).upsert(updated);
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
              );
            },
          ),
          FutureBuilder<bool>(
            future: ref.read(customerRepositoryProvider).canEdit(widget.customer.id),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                onPressed: () async {
                  final confirm = await _confirmDelete(context);
                  if (confirm) {
                    await ref
                        .read(customerRepositoryProvider)
                        .deleteById(widget.customer.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
              );
            },
          ),
          IconButton(
            onPressed: () async {
              final created = await showDialog<Sale>(
                context: context,
                builder: (_) => _SaleForCustomerDialog(
                  customerId: widget.customer.id,
                  units: units.where((unit) => unit.isActive).toList(),
                ),
              );
              if (created != null) {
                await ref.read(saleRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_shopping_cart_outlined),
            tooltip: 'Add Sale',
          ),
          IconButton(
            onPressed: () async {
              final created = await showDialog<Payment>(
                context: context,
                builder: (_) => _PaymentForCustomerDialog(
                  customerId: widget.customer.id,
                  sales: sales,
                  totalSales: totalSales,
                  totalPayments: totalPayments,
                  remainingBalance: balance,
                ),
              );
              if (created != null) {
                await ref.read(paymentRepositoryProvider).upsert(created);
              }
            },
            icon: const Icon(Icons.add_card_outlined),
            tooltip: 'Add Payment',
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _range = picked);
              }
            },
            icon: const Icon(Icons.date_range_outlined),
            label: const Text('Filter'),
          ),
          if (_range != null)
            IconButton(
              onPressed: () => setState(() => _range = null),
              icon: const Icon(Icons.clear),
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
            const SectionHeader(
              title: 'Customer Overview',
              subtitle: 'Summary and recent activity',
              icon: Icons.person_outline,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Info',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.customer.name}'),
                    Text('Phone: ${widget.customer.phone}'),
                    Text(
                        'Location: ${widget.customer.province}, ${widget.customer.district}'),
                    if (widget.customer.address != null &&
                        widget.customer.address!.isNotEmpty)
                      Text('Address: ${widget.customer.address}'),
                    const Divider(),
                    Text('Total Sales: ${formatMoney(totalSales)}'),
                    Text('Total Payments: ${formatMoney(totalPayments)}'),
                    Text('Remaining Balance: ${formatMoney(balance)}'),
                    if (lastSaleDate != null)
                      Text('Last Sale: ${formatDate(lastSaleDate)}'),
                    if (lastPaymentDate != null)
                      Text('Last Payment: ${formatDate(lastPaymentDate)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const SectionHeader(
              title: 'Ledger',
              subtitle: 'Sales and payments history',
              icon: Icons.receipt_long_outlined,
            ),
            if (rows.isEmpty)
              const EmptyStateCard(
                title: 'No transactions yet',
                subtitle: 'Add a sale or payment to see it here.',
                icon: Icons.receipt_long_outlined,
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = rows[index];
                    return ListTile(
                      leading: Icon(
                        entry.isCredit
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                      title: Text('${entry.type} • ${formatDate(entry.date)}'),
                      subtitle: Text(entry.note ?? 'No note'),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(formatMoney(entry.amount)),
                          Text('Balance: ${formatMoney(entry.runningBalance)}'),
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

class _LedgerEntry {
  const _LedgerEntry({
    required this.date,
    required this.type,
    required this.amount,
    required this.isCredit,
    this.note,
    this.runningBalance = 0,
  });

  final DateTime date;
  final String type;
  final double amount;
  final bool isCredit;
  final String? note;
  final double runningBalance;

  _LedgerEntry copyWith({double? runningBalance}) {
    return _LedgerEntry(
      date: date,
      type: type,
      amount: amount,
      isCredit: isCredit,
      note: note,
      runningBalance: runningBalance ?? this.runningBalance,
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

class _SaleForCustomerDialog extends StatefulWidget {
  const _SaleForCustomerDialog({
    required this.customerId,
    required this.units,
  });

  final String customerId;
  final List<Unit> units;

  @override
  State<_SaleForCustomerDialog> createState() => _SaleForCustomerDialogState();
}

class _SaleForCustomerDialogState extends State<_SaleForCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _unitId;
  DateTime _date = DateTime.now();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  double _totalPrice = 0;

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
      title: const Text('Add Sale'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
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
                      DropdownMenuItem(
                        value: unit.id,
                        child: Text(unit.name),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'Unit'),
                  onChanged: (value) => setState(() => _unitId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price per unit'),
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
                id: '',
                customerId: widget.customerId,
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

class _PaymentForCustomerDialog extends StatefulWidget {
  const _PaymentForCustomerDialog({
    required this.customerId,
    required this.sales,
    required this.totalSales,
    required this.totalPayments,
    required this.remainingBalance,
  });

  final String customerId;
  final List<Sale> sales;
  final double totalSales;
  final double totalPayments;
  final double remainingBalance;

  @override
  State<_PaymentForCustomerDialog> createState() =>
      _PaymentForCustomerDialogState();
}

class _PaymentForCustomerDialogState extends State<_PaymentForCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _saleId;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Total Sales'),
                  trailing: Text(formatMoney(widget.totalSales)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Total Payments'),
                  trailing: Text(formatMoney(widget.totalPayments)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Remaining Balance'),
                  trailing: Text(formatMoney(widget.remainingBalance)),
                ),
                const Divider(height: 16),
                DropdownButtonFormField<String>(
                  value: _saleId,
                  isExpanded: true,
                  items: [
                    for (final sale in widget.sales)
                      DropdownMenuItem(
                        value: sale.id,
                        child: Text(
                          '${formatDate(sale.date)} • ${formatMoney(sale.totalPrice)}',
                          overflow: TextOverflow.ellipsis,
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
                    if (parsed > widget.remainingBalance) {
                      return 'Payment exceeds remaining balance';
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
                id: '',
                customerId: widget.customerId,
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
