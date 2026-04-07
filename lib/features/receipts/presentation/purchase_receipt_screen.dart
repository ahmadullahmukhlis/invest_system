import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_utils.dart';
import '../../purchases/domain/purchase.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../units/data/unit_providers.dart';

class PurchaseReceiptScreen extends ConsumerWidget {
  const PurchaseReceiptScreen({super.key, required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    final units = ref.watch(unitsProvider);
    final payments = ref.watch(supplierPaymentsProvider);

    final supplier = suppliers.isEmpty
        ? null
        : suppliers.firstWhere(
            (item) => item.id == purchase.supplierId,
            orElse: () => suppliers.first,
          );
    final supplierName = supplier?.name ?? 'Unknown';
    final unitName = units.isEmpty
        ? ''
        : units
            .firstWhere(
              (item) => item.id == purchase.unitId,
              orElse: () => units.first,
            )
            .name;
    final related =
        payments.where((p) => p.purchaseId == purchase.id).toList();
    final paid = related.fold(0.0, (sum, item) => sum + item.amount);
    final balance = purchase.totalPrice - paid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Receipt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.indigo.withOpacity(0.15),
                  AppColors.accent.withOpacity(0.08),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase Receipt',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Receipt ID: ${purchase.id}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatDate(purchase.date),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(label: 'Total', value: formatMoney(purchase.totalPrice)),
              _StatChip(label: 'Paid', value: formatMoney(paid)),
              _StatChip(label: 'Balance', value: formatMoney(balance)),
            ],
          ),
          const SizedBox(height: 16),
          _InfoGroup(
            title: 'Supplier',
            items: [
              _InfoItem('Name', supplierName),
              _InfoItem('Phone', supplier?.phone ?? '-'),
              _InfoItem(
                'Location',
                supplier == null
                    ? '-'
                    : '${supplier.province}, ${supplier.district}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoGroup(
            title: 'Purchase Details',
            items: [
              _InfoItem('Quantity', '${purchase.quantityValue} $unitName'),
              _InfoItem(
                  'Price per unit', formatMoney(purchase.pricePerUnit)),
              _InfoItem('Total', formatMoney(purchase.totalPrice)),
              _InfoItem('Paid', formatMoney(paid)),
              _InfoItem('Balance', formatMoney(balance)),
            ],
          ),
          if (purchase.note != null && purchase.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoGroup(
              title: 'Note',
              items: [
                _InfoItem('Message', purchase.note!),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _PaymentsCard(
            title: 'Payment History',
            payments: related,
            emptyText: 'No payments recorded for this purchase.',
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bytes = await _buildPurchasePdf(
                    purchase: purchase,
                    supplierName: supplierName,
                    unitName: unitName,
                    paid: paid,
                    balance: balance,
                    note: purchase.note,
                  );
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: 'purchase-${purchase.id}.pdf',
                  );
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final bytes = await _buildPurchasePdf(
                    purchase: purchase,
                    supplierName: supplierName,
                    unitName: unitName,
                    paid: paid,
                    balance: balance,
                    note: purchase.note,
                  );
                  final path = await savePdfToDownloads(
                    context: context,
                    bytes: bytes,
                    fileName: 'purchase-${purchase.id}.pdf',
                  );
                  if (path != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved to Downloads: $path')),
                    );
                  }
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.items});

  final String title;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.value,
                        textAlign: TextAlign.end,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  _InfoItem(this.label, this.value);
  final String label;
  final String value;
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({
    required this.title,
    required this.payments,
    required this.emptyText,
  });

  final String title;
  final List<dynamic> payments;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              Text(
                emptyText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
              )
            else
              Column(
                children: [
                  for (final payment in payments) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: AppColors.success,
                          size: 18,
                        ),
                      ),
                      title: Text(formatMoney(payment.amount)),
                      subtitle: Text(formatDate(payment.date)),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> _buildPurchasePdf({
  required Purchase purchase,
  required String supplierName,
  required String unitName,
  required double paid,
  required double balance,
  String? note,
}) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Purchase Receipt',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Receipt ID: ${purchase.id}'),
            pw.Text('Date: ${formatDate(purchase.date)}'),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.Text('Supplier', style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Text('Name: $supplierName'),
            pw.SizedBox(height: 12),
            pw.Text('Purchase Details', style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Text('Quantity: ${purchase.quantityValue} $unitName'),
            pw.Text('Price per unit: ${formatMoney(purchase.pricePerUnit)}'),
            pw.Text('Total: ${formatMoney(purchase.totalPrice)}'),
            pw.Text('Paid: ${formatMoney(paid)}'),
            pw.Text('Balance: ${formatMoney(balance)}'),
            if (note != null && note.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Note: $note'),
            ],
          ],
        );
      },
    ),
  );
  return pdf.save();
}
