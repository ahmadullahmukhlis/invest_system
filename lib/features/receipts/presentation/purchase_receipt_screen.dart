import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdfs;
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
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
                      _InfoItem(
                          'Quantity', '${purchase.quantityValue} $unitName'),
                      _InfoItem('Price per unit',
                          formatMoney(purchase.pricePerUnit)),
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
                ],
              ),
            ),
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
                    phone: supplier?.phone,
                    location: supplier == null
                        ? null
                        : '${supplier.province}, ${supplier.district}',
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
                    phone: supplier?.phone,
                    location: supplier == null
                        ? null
                        : '${supplier.province}, ${supplier.district}',
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


Future<Uint8List> _buildPurchasePdf({
  required Purchase purchase,
  required String supplierName,
  required String unitName,
  required double paid,
  required double balance,
  String? phone,
  String? location,
  String? note,
}) async {
  final accent = pdfs.PdfColor.fromInt(0xFF3F8CFF);
  final indigo = pdfs.PdfColor.fromInt(0xFF1F2A44);
  final success = pdfs.PdfColor.fromInt(0xFF1F9D55);
  final muted = pdfs.PdfColor.fromInt(0xFF6B7280);
  final border = pdfs.PdfColor.fromInt(0xFFE5E7EB);
  final baseFont = await PdfGoogleFonts.nunitoRegular();
  final boldFont = await PdfGoogleFonts.nunitoBold();
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: pdfs.PdfColor.fromInt(0xFFF5F7FF),
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: border),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: pdfs.PdfColor.fromInt(0xFFE8F0FF),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text('PR',
                        style: pw.TextStyle(
                            color: accent,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Purchase Receipt',
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: indigo)),
                        pw.Text('Receipt ID: ${purchase.id}',
                            style: pw.TextStyle(color: muted)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: pdfs.PdfColor.fromInt(0xFFE8F6EE),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text(formatDate(purchase.date),
                        style: pw.TextStyle(
                            color: success, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                _pdfStat('Total', formatMoney(purchase.totalPrice), border),
                pw.SizedBox(width: 8),
                _pdfStat('Paid', formatMoney(paid), border),
                pw.SizedBox(width: 8),
                _pdfStat('Balance', formatMoney(balance), border),
              ],
            ),
            pw.SizedBox(height: 12),
            _pdfSection(
              title: 'Supplier',
              border: border,
              items: {
                'Name': supplierName,
                'Phone': phone?.isNotEmpty == true ? phone! : '-',
                'Location': location?.isNotEmpty == true ? location! : '-',
              },
            ),
            pw.SizedBox(height: 10),
            _pdfSection(
              title: 'Purchase Details',
              border: border,
              items: {
                'Quantity': '${purchase.quantityValue} $unitName',
                'Price per unit': formatMoney(purchase.pricePerUnit),
                'Total': formatMoney(purchase.totalPrice),
                'Paid': formatMoney(paid),
                'Balance': formatMoney(balance),
              },
            ),
            if (note != null && note.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              _pdfSection(
                title: 'Note',
                border: border,
                items: {'Message': note},
              ),
            ],
          ],
        );
      },
    ),
  );
  return pdf.save();
}

pw.Widget _pdfSection({
  required String title,
  required pdfs.PdfColor border,
  required Map<String, String> items,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: border),
      borderRadius: pw.BorderRadius.circular(10),
      color: pdfs.PdfColor.fromInt(0xFFFFFFFF),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final entry in items.entries)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(entry.key,
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: pdfs.PdfColor.fromInt(0xFF6B7280))),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(entry.value,
                      textAlign: pw.TextAlign.right,
                      style:  pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _pdfStat(String label, String value, pdfs.PdfColor border) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9, color: pdfs.PdfColor.fromInt(0xFF6B7280))),
          pw.SizedBox(height: 3),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
}
