import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../payments/data/payment_providers.dart';
import '../../sales/data/sale_providers.dart';
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
        child: Card(
          child: ListView.separated(
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
