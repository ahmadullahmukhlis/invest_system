import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/geo_data.dart';
import '../../../core/data/geo_providers.dart';
import '../domain/supplier.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({super.key, this.existing});

  final Supplier? existing;

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  String? _province;
  String? _district;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _province = widget.existing?.province;
    _district = widget.existing?.district;
    _address = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provinceAsync = ref.watch(provinceDataProvider);
    final provinces = provinceAsync.value ?? const [];
    final isLoading = provinceAsync.isLoading;
    if (_province != null &&
        provinces.isNotEmpty &&
        !provinces.any((item) => item.name == _province)) {
      _province = null;
      _district = null;
    }
    final selectedProvince = provinces.firstWhere(
      (item) => item.name == _province,
      orElse: () => provinces.isNotEmpty ? provinces.first : _emptyProvince,
    );
    final districtOptions =
        _province == null ? const <String>[] : selectedProvince.districts;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Supplier' : 'Edit Supplier'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _province,
                  items: [
                    for (final item in provinces)
                      DropdownMenuItem(
                        value: item.name,
                        child: Text(item.name),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'Province'),
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _province = value;
                            _district = null;
                          });
                        },
                  disabledHint:
                      isLoading ? const Text('Loading provinces...') : null,
                  isExpanded: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _district,
                  items: [
                    for (final item in districtOptions)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      )
                  ],
                  decoration: const InputDecoration(labelText: 'District'),
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _district = value),
                  disabledHint:
                      isLoading ? const Text('Select province first') : null,
                  isExpanded: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                if (provinceAsync.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Province data not loaded. Run flutter pub get and restart the app.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final updated = Supplier(
              id: widget.existing?.id ?? '',
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              province: _province ?? '',
              district: _district ?? '',
              address: _address.text.trim().isEmpty
                  ? null
                  : _address.text.trim(),
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

const _emptyProvince = ProvinceData(name: '', districts: []);
