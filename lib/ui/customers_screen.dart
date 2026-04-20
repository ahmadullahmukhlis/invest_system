import 'package:flutter/material.dart';

import '../data/customer.dart';
import '../data/customer_repository.dart';
import '../data/permissions.dart';
import 'responsive.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });

  final CustomerRepository repository;
  final PermissionSet? permissions;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perms = widget.permissions ??
        PermissionSet(view: false, create: false, edit: false, remove: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
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
                  hintText: 'Search customers',
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
            child: StreamBuilder<List<Customer>>(
              stream: widget.repository.stream,
              builder: (context, snapshot) {
                final customers = snapshot.data ?? const [];
                final filtered = customers.where((customer) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return customer.name.toLowerCase().contains(q) ||
                      customer.phone.toLowerCase().contains(q) ||
                      customer.email.toLowerCase().contains(q) ||
                      customer.company.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No customers yet'));
                }

                return Responsive.centered(
                  context,
                  ListView.separated(
                    padding: Responsive.pagePadding(context),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
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
                          onTap: perms.edit ? () => _openForm(customer) : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFE7EAF6),
                                    child: Text(
                                      customer.name.isEmpty
                                          ? '?'
                                          : customer.name[0].toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer.name,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          customer.company,
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (customer.dirty)
                                    const Icon(Icons.sync, size: 18),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                customer.phone,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                customer.email,
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
        heroTag: 'fab_customers',
        onPressed: perms.create ? () => _openForm(null) : null,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openForm(Customer? customer) async {
    final isEditing = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final addressController =
        TextEditingController(text: customer?.address ?? '');
    final companyController =
        TextEditingController(text: customer?.company ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');

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
          child: Responsive.centered(
            context,
            ListView(
              shrinkWrap: true,
              children: [
                Text(
                  isEditing ? 'Edit Customer' : 'New Customer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _Field(label: 'Name', controller: nameController),
                _Field(label: 'Phone', controller: phoneController),
                _Field(label: 'Email', controller: emailController),
                _Field(label: 'Address', controller: addressController),
                _Field(label: 'Company', controller: companyController),
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
                    if (isEditing) {
                      await widget.repository.updateCustomer(
                        customer!.copyWith(
                          name: name,
                          phone: phoneController.text.trim(),
                          email: emailController.text.trim(),
                          address: addressController.text.trim(),
                          company: companyController.text.trim(),
                          notes: notesController.text.trim(),
                        ),
                      );
                    } else {
                      await widget.repository.addCustomer(
                        name: name,
                        phone: phoneController.text.trim(),
                        email: emailController.text.trim(),
                        address: addressController.text.trim(),
                        company: companyController.text.trim(),
                        notes: notesController.text.trim(),
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
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
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
