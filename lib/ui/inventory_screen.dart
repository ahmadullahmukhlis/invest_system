import 'package:flutter/material.dart';

import '../data/product.dart';
import '../data/product_repository.dart';
import '../data/permissions.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });

  final ProductRepository repository;
  final PermissionSet? permissions;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final perms = widget.permissions ??
        PermissionSet(view: false, create: false, edit: false, remove: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search stock',
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
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: widget.repository.stream,
              builder: (context, snapshot) {
                final products = snapshot.data ?? const [];
                final filtered = products.where((product) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return product.name.toLowerCase().contains(q) ||
                      product.sku.toLowerCase().contains(q) ||
                      product.category.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No stock yet'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stock: ${product.stock} ${product.unit}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed:
                                perms.edit ? () => _adjustStock(product) : null,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(Product product) async {
    final deltaController = TextEditingController();
    final reasonController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Adjust Stock',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Product: ${product.name}'),
              const SizedBox(height: 12),
              TextField(
                controller: deltaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Change (+ / -)',
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final delta =
                      double.tryParse(deltaController.text.trim()) ?? 0;
                  if (delta == 0) return;
                  final updated = product.copyWith(
                    stock: product.stock + delta,
                    notes: reasonController.text.trim().isEmpty
                        ? product.notes
                        : '${product.notes}\nStock change: ${reasonController.text.trim()}',
                  );
                  await widget.repository.updateProduct(updated);
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }
}
