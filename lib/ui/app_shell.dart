import 'package:flutter/material.dart';

import '../data/customer_repository.dart';
import '../data/product_repository.dart';
import '../data/permissions.dart';
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
    return StreamBuilder(
      stream: widget.userRepository.currentUserStream,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? widget.userRepository.current;
        final email = widget.userRepository.currentEmail.toLowerCase();
        final role = profile?.role ??
            (email == UserRepository.superAdminEmail
                ? 'super_admin'
                : 'viewer');
        final basePerms = profile?.permissions ?? {};
        final effectivePerms = basePerms.isEmpty
            ? defaultPermissionsForRole(role)
            : basePerms;

        bool canView(String module) {
          if (role == 'super_admin') return true;
          return effectivePerms[module]?.view ?? false;
        }

        final pages = <Widget>[];
        final destinations = <NavigationDestination>[];

        pages.add(
          DashboardScreen(
            customerRepository: widget.customerRepository,
            productRepository: widget.productRepository,
            vendorRepository: widget.vendorRepository,
            purchaseRepository: widget.purchaseRepository,
          ),
        );
        destinations.add(const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ));

        if (canView('customers')) {
          pages.add(
            CustomersScreen(
              repository: widget.customerRepository,
              permissions: effectivePerms['customers'],
            ),
          );
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ));
        }

        if (canView('products')) {
          pages.add(
            ProductsScreen(
              repository: widget.productRepository,
              permissions: effectivePerms['products'],
            ),
          );
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ));
        }

        pages.add(
          MoreScreen(
            vendorRepository: widget.vendorRepository,
            purchaseRepository: widget.purchaseRepository,
            productRepository: widget.productRepository,
            customerRepository: widget.customerRepository,
            userRepository: widget.userRepository,
            permissions: effectivePerms,
            role: role,
          ),
        );
        destinations.add(const NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'More',
        ));

        final safeIndex = _index.clamp(0, pages.length - 1);
        if (safeIndex != _index) {
          _index = safeIndex;
        }

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
            destinations: destinations,
          ),
        );
      },
    );
  }
}
