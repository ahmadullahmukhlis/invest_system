import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/widgets/desktop_scaffold.dart';
import '../../../core/widgets/desktop_table.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../ui/responsive.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../purchases/domain/purchase.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/supplier_payment_providers.dart';
import '../domain/supplier_payment.dart';
import '../../../data/user_providers.dart';

class SupplierPaymentsScreen extends ConsumerWidget {
  const SupplierPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final payments = ref.watch(supplierPaymentsProvider);
    final suppliers = ref.watch(suppliersProvider);
    final purchases = ref.watch(purchasesProvider);
    final canCreateSupplierPayment = canCreate(userRepo, 'supplier_payments');
    final canEditSupplierPayment = canEdit(userRepo, 'supplier_payments');
    final canDeleteSupplierPayment = canRemove(userRepo, 'supplier_payments');

    final isDesktop = Responsive.isDesktop(context);

    return DesktopScaffold(
      title: 'Supplier Payments',
      actions: [
        if (canCreateSupplierPayment)
          IconButton(
            onPressed: () async {
              final created = await showDialog<SupplierPayment>(
                context: context,
                builder: (_) => _SupplierPaymentFormDialog(
                  suppliers: suppliers,
                  purchases: purchases,
                  payments: payments,
                  existing: null,
                ),
              );
              if (created != null) {
                await ref
                    .read(supplierPaymentRepositoryProvider)
                    .upsert(created);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Record payment',
          ),
      ],
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Supplier Payments',
              subtitle: '${payments.length} records',
              icon: Icons.account_balance_wallet_outlined,
            ),
            if (payments.isEmpty)
              const EmptyStateCard(
                title: 'No supplier payments yet',
                subtitle: 'Record supplier payments to track balances.',
                icon: Icons.account_balance_wallet_outlined,
              )
            else if (isDesktop)
              DesktopTable(
                minWidth: 900,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final payment in payments)
                    _buildSupplierPaymentRow(
                      context,
                      ref,
                      payment: payment,
                      suppliers: suppliers,
                      purchases: purchases,
                      payments: payments,
                      canEditSupplierPayment: canEditSupplierPayment,
                      canDeleteSupplierPayment: canDeleteSupplierPayment,
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (final payment in payments) ...[
                    _buildSupplierPaymentCard(
                      context,
                      ref,
                      payment: payment,
                      suppliers: suppliers,
                      purchases: purchases,
                      payments: payments,
                      canEditSupplierPayment: canEditSupplierPayment,
                      canDeleteSupplierPayment: canDeleteSupplierPayment,
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
}

DataRow _buildSupplierPaymentRow(
  BuildContext context,
  WidgetRef ref, {
  required SupplierPayment payment,
  required List<Supplier> suppliers,
  required List<Purchase> purchases,
  required List<SupplierPayment> payments,
  required bool canEditSupplierPayment,
  required bool canDeleteSupplierPayment,
}) {
  final supplierName = suppliers.isEmpty
      ? 'Unknown'
      : suppliers
            .firstWhere(
              (item) => item.id == payment.supplierId,
              orElse: () => suppliers.first,
            )
            .name;

  return DataRow(
    cells: [
      DataCell(Text(formatDate(payment.date))),
      DataCell(Text(supplierName)),
      DataCell(Text(formatMoney(payment.amount))),
      DataCell(
        Align(
          alignment: Alignment.centerLeft,
          child: _buildSupplierPaymentActionsMenu(
            context,
            ref,
            payment,
            suppliers,
            purchases,
            payments,
            canEditSupplierPayment: canEditSupplierPayment,
            canDeleteSupplierPayment: canDeleteSupplierPayment,
          ),
        ),
      ),
    ],
  );
}

Widget _buildSupplierPaymentCard(
  BuildContext context,
  WidgetRef ref, {
  required SupplierPayment payment,
  required List<Supplier> suppliers,
  required List<Purchase> purchases,
  required List<SupplierPayment> payments,
  required bool canEditSupplierPayment,
  required bool canDeleteSupplierPayment,
}) {
  final supplierName = suppliers.isEmpty
      ? 'Unknown'
      : suppliers
            .firstWhere(
              (item) => item.id == payment.supplierId,
              orElse: () => suppliers.first,
            )
            .name;

  return Card(
    child: ListTile(
      title: Text(supplierName),
      subtitle: Text(
        '${formatDate(payment.date)} • ${formatMoney(payment.amount)}',
      ),
      trailing: _buildSupplierPaymentActionsMenu(
        context,
        ref,
        payment,
        suppliers,
        purchases,
        payments,
        canEditSupplierPayment: canEditSupplierPayment,
        canDeleteSupplierPayment: canDeleteSupplierPayment,
      ),
    ),
  );
}

Widget _buildSupplierPaymentActionsMenu(
  BuildContext context,
  WidgetRef ref,
  SupplierPayment payment,
  List<Supplier> suppliers,
  List<Purchase> purchases,
  List<SupplierPayment> payments, {
  required bool canEditSupplierPayment,
  required bool canDeleteSupplierPayment,
}) {
  if (!canEditSupplierPayment && !canDeleteSupplierPayment) {
    return const SizedBox.shrink();
  }

  return PopupMenuButton<String>(
    onSelected: (value) async {
      final canEdit = await ref
          .read(supplierPaymentRepositoryProvider)
          .canEdit(payment.id);
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
        final updated = await showDialog<SupplierPayment>(
          context: context,
          builder: (_) => _SupplierPaymentFormDialog(
            suppliers: suppliers,
            purchases: purchases,
            payments: payments,
            existing: payment,
          ),
        );
        if (updated != null) {
          await ref.read(supplierPaymentRepositoryProvider).upsert(updated);
        }
      }
      if (value == 'delete') {
        final confirm = await _confirmDelete(context);
        if (confirm) {
          await ref
              .read(supplierPaymentRepositoryProvider)
              .deleteById(payment.id);
        }
      }
    },
    itemBuilder: (_) => [
      if (canEditSupplierPayment)
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (canDeleteSupplierPayment)
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );
}

class _SupplierPaymentFormDialog extends StatefulWidget {
  const _SupplierPaymentFormDialog({
    required this.suppliers,
    required this.purchases,
    required this.payments,
    required this.existing,
  });

  final List<Supplier> suppliers;
  final List<Purchase> purchases;
  final List<SupplierPayment> payments;
  final SupplierPayment? existing;

  @override
  State<_SupplierPaymentFormDialog> createState() =>
      _SupplierPaymentFormDialogState();
}

class _SupplierPaymentFormDialogState
    extends State<_SupplierPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _supplierId;
  String? _purchaseId;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _supplierId = existing.supplierId;
      _purchaseId = existing.purchaseId;
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

  double _balanceForSupplier(String supplierId) {
    final purchases = widget.purchases
        .where((purchase) => purchase.supplierId == supplierId)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
    final payments = widget.payments
        .where((payment) => payment.supplierId == supplierId)
        .fold(0.0, (sum, item) => sum + item.amount);
    return purchases - payments;
  }

  @override
  Widget build(BuildContext context) {
    final supplierPurchases = _supplierId == null
        ? 0.0
        : widget.purchases
              .where((purchase) => purchase.supplierId == _supplierId)
              .fold(0.0, (sum, item) => sum + item.totalPrice);
    final supplierPayments = _supplierId == null
        ? 0.0
        : widget.payments
              .where((payment) => payment.supplierId == _supplierId)
              .fold(0.0, (sum, item) => sum + item.amount);
    final balance = supplierPurchases - supplierPayments;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Supplier Payment'
            : 'Edit Supplier Payment',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _supplierId,
                  items: [
                    for (final supplier in widget.suppliers)
                      DropdownMenuItem(
                        value: supplier.id,
                        child: Text(supplier.name),
                      ),
                  ],
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  onChanged: (value) => setState(() {
                    _supplierId = value;
                    _purchaseId = null;
                  }),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (_supplierId != null)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supplier Summary',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Purchases'),
                              Text(formatMoney(supplierPurchases)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Payments'),
                              Text(formatMoney(supplierPayments)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Remaining Balance'),
                              Text(formatMoney(balance)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_supplierId != null) const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _purchaseId,
                  isExpanded: true,
                  items: [
                    for (final purchase in widget.purchases.where(
                      (purchase) => purchase.supplierId == _supplierId,
                    ))
                      DropdownMenuItem(
                        value: purchase.id,
                        child: Text(
                          '${formatDate(purchase.date)} • ${formatMoney(purchase.totalPrice)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Purchase (optional)',
                  ),
                  onChanged: (value) => setState(() => _purchaseId = value),
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
                    if (_supplierId != null && parsed > balance) {
                      return 'Payment exceeds balance';
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
                  title: const Text('Current Balance'),
                  trailing: Text(formatMoney(balance)),
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
              SupplierPayment(
                id: widget.existing?.id ?? '',
                supplierId: _supplierId!,
                purchaseId: _purchaseId,
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
      title: const Text('Delete supplier payment?'),
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
