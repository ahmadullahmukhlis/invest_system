import 'package:flutter/material.dart';

import '../data/customer_repository.dart';
import '../data/product_repository.dart';
import '../data/purchase_repository.dart';
import '../data/user_repository.dart';
import '../data/vendor_repository.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'products_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.customerRepository,
    required this.productRepository,
    required this.vendorRepository,
    required this.purchaseRepository,
    required this.userRepository,
  });

  final CustomerRepository customerRepository;
  final ProductRepository productRepository;
  final VendorRepository vendorRepository;
  final PurchaseRepository purchaseRepository;
  final UserRepository userRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        customerRepository: widget.customerRepository,
        productRepository: widget.productRepository,
        vendorRepository: widget.vendorRepository,
        purchaseRepository: widget.purchaseRepository,
      ),
      CustomersScreen(repository: widget.customerRepository),
      ProductsScreen(repository: widget.productRepository),
      MoreScreen(
        vendorRepository: widget.vendorRepository,
        purchaseRepository: widget.purchaseRepository,
        productRepository: widget.productRepository,
        customerRepository: widget.customerRepository,
        userRepository: widget.userRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
