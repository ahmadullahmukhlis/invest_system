import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/purchase.dart';
import '../data/purchase_repository.dart';
import '../data/permissions.dart';
import 'responsive.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });

  final PurchaseRepository repository;
  final PermissionSet? permissions;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String _query = '';
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perms = widget.permissions ??
        PermissionSet(view: false, create: false, edit: false, remove: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: Responsive.pagePadding(context).copyWith(bottom: 8),
            child: Responsive.centered(
              context,
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search purchases',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF2F3F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Purchase>>(
              stream: widget.repository.stream,
              builder: (context, snapshot) {
                final purchases = snapshot.data ?? const [];
                final filtered = purchases.where((purchase) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return purchase.vendorName.toLowerCase().contains(q) ||
                      purchase.reference.toLowerCase().contains(q) ||
                      purchase.status.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No purchases yet'));
                }

                return Responsive.centered(
                  context,
                  ListView.separated(
                    padding: Responsive.pagePadding(context),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final purchase = filtered[index];
                      final date = purchase.purchasedAt == 0
                          ? 'No date'
                          : _dateFormat
                              .format(DateTime.fromMillisecondsSinceEpoch(
                                  purchase.purchasedAt));
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: perms.edit ? () => _openForm(purchase) : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFE7EAF6),
                                    child: const Icon(Icons.receipt_long),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          purchase.vendorName,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          purchase.reference,
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (purchase.dirty)
                                    const Icon(Icons.sync, size: 18),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Total: ${purchase.total.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                'Status: ${purchase.status}',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                'Date: $date',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_purchases',
        onPressed: perms.create ? () => _openForm(null) : null,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openForm(Purchase? purchase) async {
    final isEditing = purchase != null;
    final vendorController =
        TextEditingController(text: purchase?.vendorName ?? '');
    final referenceController =
        TextEditingController(text: purchase?.reference ?? '');
    final totalController = TextEditingController(
      text: purchase == null ? '' : purchase.total.toString(),
    );
    final notesController = TextEditingController(text: purchase?.notes ?? '');
    String status = purchase?.status ?? 'Draft';
    int purchasedAt = purchase?.purchasedAt ??
        DateTime.now().millisecondsSinceEpoch;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateLabel = _dateFormat
                .format(DateTime.fromMillisecondsSinceEpoch(purchasedAt));
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
              child: Responsive.centered(
                context,
                ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      isEditing ? 'Edit Purchase' : 'New Purchase',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _Field(label: 'Vendor', controller: vendorController),
                    _Field(label: 'Reference', controller: referenceController),
                    _Field(
                      label: 'Total',
                      controller: totalController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'Ordered', child: Text('Ordered')),
                        DropdownMenuItem(value: 'Received', child: Text('Received')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => status = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: DateTime.fromMillisecondsSinceEpoch(
                              purchasedAt),
                        );
                        if (picked != null) {
                          setModalState(() {
                            purchasedAt = picked.millisecondsSinceEpoch;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Date: $dateLabel'),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'Notes',
                      controller: notesController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final vendor = vendorController.text.trim();
                        if (vendor.isEmpty) return;
                        final total =
                            double.tryParse(totalController.text.trim()) ?? 0;
                        if (isEditing) {
                          await widget.repository.updatePurchase(
                            purchase!.copyWith(
                              vendorName: vendor,
                              reference: referenceController.text.trim(),
                              total: total,
                              status: status,
                              notes: notesController.text.trim(),
                              purchasedAt: purchasedAt,
                            ),
                          );
                        } else {
                          await widget.repository.addPurchase(
                            vendorName: vendor,
                            reference: referenceController.text.trim(),
                            total: total,
                            status: status,
                            notes: notesController.text.trim(),
                            purchasedAt: purchasedAt,
                          );
                        }
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: Text(isEditing ? 'Save' : 'Create'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF7F7F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
