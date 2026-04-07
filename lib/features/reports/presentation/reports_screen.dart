import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/data/geo_providers.dart';
import '../../../core/data/geo_data.dart';
import '../../../core/widgets/refresh_wrapper.dart';
import '../../../core/widgets/section_header.dart';
import '../../customers/data/customer_providers.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../sales/data/sale_providers.dart';
import '../../suppliers/data/supplier_providers.dart';
import '../../units/data/unit_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange? _range;
  String? _province;
  String? _district;
  String? _unitId;

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final suppliers = ref.watch(suppliersProvider);
    final sales = ref.watch(salesProvider);
    final purchases = ref.watch(purchasesProvider);
    final units = ref.watch(unitsProvider);
    final provinceAsync = ref.watch(provinceDataProvider);
    final provincesData = provinceAsync.value ?? const [];

    final provinces = provincesData.map((p) => p.name).toList();
    final selectedProvince = provincesData.firstWhere(
      (item) => item.name == _province,
      orElse: () =>
          provincesData.isNotEmpty ? provincesData.first : _emptyProvince,
    );
    final districts =
        _province == null ? const <String>[] : selectedProvince.districts;

    final filteredSales = sales.where((sale) {
      if (_range != null) {
        if (sale.date.isBefore(_range!.start) ||
            sale.date.isAfter(_range!.end)) {
          return false;
        }
      }
      if (_unitId != null && sale.unitId != _unitId) return false;
      if (customers.isEmpty) return false;
      final customer = customers.firstWhere(
        (item) => item.id == sale.customerId,
        orElse: () => customers.first,
      );
      if (_province != null && customer.province != _province) return false;
      if (_district != null && customer.district != _district) return false;
      return true;
    }).toList();

    final filteredPurchases = purchases.where((purchase) {
      if (_range != null) {
        if (purchase.date.isBefore(_range!.start) ||
            purchase.date.isAfter(_range!.end)) {
          return false;
        }
      }
      if (_unitId != null && purchase.unitId != _unitId) return false;
      if (suppliers.isEmpty) return false;
      final supplier = suppliers.firstWhere(
        (item) => item.id == purchase.supplierId,
        orElse: () => suppliers.first,
      );
      if (_province != null && supplier.province != _province) return false;
      if (_district != null && supplier.district != _district) return false;
      return true;
    }).toList();

    final totalSales =
        filteredSales.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalPurchases =
        filteredPurchases.fold(0.0, (sum, item) => sum + item.totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: RefreshWrapper(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
          const SectionHeader(
            title: 'Filters',
            subtitle: 'Narrow down sales and purchases',
            icon: Icons.tune,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      value: _province,
                      isExpanded: true,
                      items: [
                        for (final item in provinces)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      decoration: const InputDecoration(labelText: 'Province'),
                    onChanged: provinceAsync.isLoading
                        ? null
                        : (value) => setState(() {
                              _province = value;
                              _district = null;
                            }),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      value: _district,
                      isExpanded: true,
                      items: [
                        for (final item in districts)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      decoration: const InputDecoration(labelText: 'District'),
                    onChanged: provinceAsync.isLoading
                        ? null
                        : (value) => setState(() => _district = value),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _unitId,
                      isExpanded: true,
                      items: [
                        for (final unit in units)
                          DropdownMenuItem(
                            value: unit.id,
                            child: Text(unit.name),
                          ),
                      ],
                      decoration: const InputDecoration(labelText: 'Unit'),
                      onChanged: (value) => setState(() => _unitId = value),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _range = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _range == null
                          ? 'Pick Date Range'
                          : '${formatDate(_range!.start)} to ${formatDate(_range!.end)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _range = null;
                      _province = null;
                      _district = null;
                      _unitId = null;
                    }),
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Summary',
            subtitle: 'Totals based on applied filters',
            icon: Icons.analytics_outlined,
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ReportCard(
                title: 'Daily Sales',
                value: formatMoney(totalSales),
                subtitle: 'Filtered sales total',
              ),
              _ReportCard(
                title: 'Daily Purchases',
                value: formatMoney(totalPurchases),
                subtitle: 'Filtered purchase total',
              ),
              _ReportCard(
                title: 'Customer Report',
                value: '${filteredSales.length} sales',
                subtitle: 'Based on filters',
              ),
              _ReportCard(
                title: 'Supplier Report',
                value: '${filteredPurchases.length} purchases',
                subtitle: 'Based on filters',
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

const _emptyProvince = ProvinceData(name: '', districts: []);
