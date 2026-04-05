import 'package:flutter/material.dart';

import '../data/product.dart';
import '../data/product_repository.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.repository});

  final ProductRepository repository;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products',
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
                  return const Center(child: Text('No products yet'));
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
                      child: InkWell(
                        onTap: () => _openForm(product),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFE7EAF6),
                                  child: Text(
                                    product.name.isEmpty
                                        ? '?'
                                        : product.name[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.sku,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (product.dirty)
                                  const Icon(Icons.sync, size: 18),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Category: ${product.category}',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Stock: ${product.stock} ${product.unit}',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Price: ${product.price.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openForm(Product? product) async {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final categoryController =
        TextEditingController(text: product?.category ?? '');
    final unitController = TextEditingController(text: product?.unit ?? '');
    final priceController = TextEditingController(
      text: product == null ? '' : product.price.toString(),
    );
    final costController = TextEditingController(
      text: product == null ? '' : product.cost.toString(),
    );
    final stockController = TextEditingController(
      text: product == null ? '' : product.stock.toString(),
    );
    final notesController = TextEditingController(text: product?.notes ?? '');

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
                isEditing ? 'Edit Product' : 'New Product',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _Field(label: 'Name', controller: nameController),
              _Field(label: 'SKU', controller: skuController),
              _Field(label: 'Category', controller: categoryController),
              _Field(label: 'Unit', controller: unitController),
              _Field(
                label: 'Price',
                controller: priceController,
                keyboardType: TextInputType.number,
              ),
              _Field(
                label: 'Cost',
                controller: costController,
                keyboardType: TextInputType.number,
              ),
              _Field(
                label: 'Stock',
                controller: stockController,
                keyboardType: TextInputType.number,
              ),
              _Field(
                label: 'Notes',
                controller: notesController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final price =
                      double.tryParse(priceController.text.trim()) ?? 0;
                  final cost = double.tryParse(costController.text.trim()) ?? 0;
                  final stock =
                      double.tryParse(stockController.text.trim()) ?? 0;

                  if (isEditing) {
                    await widget.repository.updateProduct(
                      product!.copyWith(
                        name: name,
                        sku: skuController.text.trim(),
                        category: categoryController.text.trim(),
                        unit: unitController.text.trim(),
                        price: price,
                        cost: cost,
                        stock: stock,
                        notes: notesController.text.trim(),
                      ),
                    );
                  } else {
                    await widget.repository.addProduct(
                      name: name,
                      sku: skuController.text.trim(),
                      category: categoryController.text.trim(),
                      unit: unitController.text.trim(),
                      price: price,
                      cost: cost,
                      stock: stock,
                      notes: notesController.text.trim(),
                    );
                  }
                  if (mounted) Navigator.of(context).pop();
                },
                child: Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          ),
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
