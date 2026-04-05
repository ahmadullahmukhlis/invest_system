import 'package:flutter/material.dart';

import '../data/vendor.dart';
import '../data/vendor_repository.dart';
import '../data/permissions.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });

  final VendorRepository repository;
  final PermissionSet? permissions;

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perms = widget.permissions ??
        PermissionSet(view: false, create: false, edit: false, remove: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search vendors',
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
            child: StreamBuilder<List<Vendor>>(
              stream: widget.repository.stream,
              builder: (context, snapshot) {
                final vendors = snapshot.data ?? const [];
                final filtered = vendors.where((vendor) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return vendor.name.toLowerCase().contains(q) ||
                      vendor.phone.toLowerCase().contains(q) ||
                      vendor.email.toLowerCase().contains(q) ||
                      vendor.company.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No vendors yet'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vendor = filtered[index];
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
                        onTap: perms.edit ? () => _openForm(vendor) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFE7EAF6),
                                  child: Text(
                                    vendor.name.isEmpty
                                        ? '?'
                                        : vendor.name[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vendor.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        vendor.company,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (vendor.dirty)
                                  const Icon(Icons.sync, size: 18),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              vendor.phone,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              vendor.email,
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
        onPressed: perms.create ? () => _openForm(null) : null,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openForm(Vendor? vendor) async {
    final isEditing = vendor != null;
    final nameController = TextEditingController(text: vendor?.name ?? '');
    final phoneController = TextEditingController(text: vendor?.phone ?? '');
    final emailController = TextEditingController(text: vendor?.email ?? '');
    final addressController =
        TextEditingController(text: vendor?.address ?? '');
    final companyController =
        TextEditingController(text: vendor?.company ?? '');
    final notesController = TextEditingController(text: vendor?.notes ?? '');

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
                isEditing ? 'Edit Vendor' : 'New Vendor',
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
                    await widget.repository.updateVendor(
                      vendor!.copyWith(
                        name: name,
                        phone: phoneController.text.trim(),
                        email: emailController.text.trim(),
                        address: addressController.text.trim(),
                        company: companyController.text.trim(),
                        notes: notesController.text.trim(),
                      ),
                    );
                  } else {
                    await widget.repository.addVendor(
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
