import 'package:flutter/material.dart';

import '../data/customer.dart';
import '../data/customer_repository.dart';
import '../data/product.dart';
import '../data/product_repository.dart';
import '../data/purchase.dart';
import '../data/purchase_repository.dart';
import 'responsive.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.customerRepository,
    required this.productRepository,
    required this.purchaseRepository,
  });

  final CustomerRepository customerRepository;
  final ProductRepository productRepository;
  final PurchaseRepository purchaseRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: false,
      ),
      body: Responsive.centered(
        context,
        ListView(
          padding: Responsive.pagePadding(context),
          children: [
            _ReportCard<Customer>(
              title: 'Customers',
              subtitle: 'Total customers in system',
              stream: customerRepository.stream,
              icon: Icons.people_alt,
            ),
            const SizedBox(height: 12),
            _ReportCard<Product>(
              title: 'Products',
              subtitle: 'Total products listed',
              stream: productRepository.stream,
              icon: Icons.inventory_2,
            ),
            const SizedBox(height: 12),
            _ReportCard<Purchase>(
              title: 'Purchases',
              subtitle: 'Orders tracked',
              stream: purchaseRepository.stream,
              icon: Icons.receipt_long,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard<T> extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.stream,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Stream<List<T>> stream;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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
      child: StreamBuilder<List<T>>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;
          return Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE7EAF6),
                child: Icon(icon, color: const Color(0xFF2A3A6A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
