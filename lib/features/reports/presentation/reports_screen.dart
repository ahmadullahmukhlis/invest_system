import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invest_system/features/units/domain/unit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
import '../../payments/data/payment_providers.dart';

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

  DateTimeRange _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _monthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _yearRange() {
    final now = DateTime.now();
    final start = DateTime(now.year);
    final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _exportCustomerReport({
    required List<_CustomerReportRow> rows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Customers'];
    sheet.appendRow([
      TextCellValue('Customer'),
      TextCellValue('Phone'),
      TextCellValue('Province'),
      TextCellValue('District'),
      TextCellValue('Sales Count'),
      TextCellValue('Total Quantity'),
      TextCellValue('Unit Breakdown'),
      TextCellValue('Total Sales'),
      TextCellValue('Total Payments'),
      TextCellValue('Balance'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.name),
        TextCellValue(row.phone),
        TextCellValue(row.province),
        TextCellValue(row.district),
        IntCellValue(row.salesCount),
        DoubleCellValue(row.totalQuantity),
        TextCellValue(row.unitBreakdown),
        DoubleCellValue(row.totalSales),
        DoubleCellValue(row.totalPayments),
        DoubleCellValue(row.balance),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/customer_report.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Customer report',
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final suppliers = ref.watch(suppliersProvider);
    final sales = ref.watch(salesProvider);
    final purchases = ref.watch(purchasesProvider);
    final units = ref.watch(unitsProvider);
    final payments = ref.watch(paymentsProvider);
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

    final unitNames = {
      for (final unit in units) unit.id: unit.name,
    };

    final customerRows = customers.map((customer) {
      final customerSales = filteredSales
          .where((sale) => sale.customerId == customer.id)
          .toList();
      final customerPayments = payments
          .where((payment) => payment.customerId == customer.id)
          .toList();
      final salesCount = customerSales.length;
      final totalSales = customerSales.fold(
        0.0,
            (sum, item) => sum + item.totalPrice,
      );
      final totalPayments = customerPayments.fold(
        0.0,
            (sum, item) => sum + item.amount,
      );
      final balance = totalSales - totalPayments;
      final quantityByUnit = <String, double>{};
      double totalQuantity = 0;
      for (final sale in customerSales) {
        totalQuantity += sale.quantityValue;
        final key = unitNames[sale.unitId] ?? 'Unknown';
        quantityByUnit[key] = (quantityByUnit[key] ?? 0) + sale.quantityValue;
      }
      final unitBreakdown = quantityByUnit.entries.isEmpty
          ? '-'
          : quantityByUnit.entries
          .map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}')
          .join(' | ');
      return _CustomerReportRow(
        name: customer.name,
        phone: customer.phone,
        province: customer.province,
        district: customer.district,
        salesCount: salesCount,
        totalQuantity: totalQuantity,
        unitBreakdown: unitBreakdown,
        totalSales: totalSales,
        totalPayments: totalPayments,
        balance: balance,
      );
    }).where((row) {
      if (_province != null && row.province != _province) return false;
      if (_district != null && row.district != _district) return false;
      if (_unitId != null) {
        final unitName = unitNames[_unitId] ?? '';
        if (!row.unitBreakdown.contains(unitName)) return false;
      }
      if (_range != null && row.salesCount == 0) return false;
      return true;
    }).toList();

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Section
                  _buildFilterSection(provinces, districts, units, provinceAsync.isLoading, constraints.maxWidth),
                  const SizedBox(height: 24),

                  // Summary Section
                  _buildSummarySection(totalSales, totalPurchases, customerRows.length, filteredPurchases.length, constraints.maxWidth),
                  const SizedBox(height: 24),

                  // Customer Report Section
                  _buildCustomerReportSection(customerRows, unitNames, constraints.maxWidth),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSection(List<String> provinces, List<String> districts, List<Unit> units, bool isLoading, double maxWidth) {
    final isMobile = maxWidth < 600;
    final isTablet = maxWidth >= 600 && maxWidth < 1200;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.filter_alt_outlined, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filter Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _range = null;
                    _province = null;
                    _district = null;
                    _unitId = null;
                  }),
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: isMobile ? const SizedBox() : const Text('Clear All'),
                  style: TextButton.styleFrom(
                    padding: isMobile ? const EdgeInsets.all(8) : null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                Wrap(
                  spacing: isMobile ? 8 : 16,
                  runSpacing: isMobile ? 12 : 16,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : (isTablet ? 180 : 200),
                      child: DropdownButtonFormField<String>(
                        value: _province,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Provinces')),
                          for (final item in provinces)
                            DropdownMenuItem(value: item, child: Text(item)),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Province',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 16),
                        ),
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() {
                          _province = value;
                          _district = null;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : (isTablet ? 180 : 200),
                      child: DropdownButtonFormField<String>(
                        value: _district,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Districts')),
                          for (final item in districts)
                            DropdownMenuItem(value: item, child: Text(item)),
                        ],
                        decoration: InputDecoration(
                          labelText: 'District',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.map_outlined, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 16),
                        ),
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _district = value),
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : (isTablet ? 180 : 200),
                      child: DropdownButtonFormField<String>(
                        value: _unitId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Units')),
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.calculate_outlined, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 16),
                        ),
                        onChanged: (value) => setState(() => _unitId = value),
                      ),
                    ),
                    Container(
                      constraints: BoxConstraints(minWidth: isMobile ? double.infinity : 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 14),
                              minimumSize: isMobile ? const Size(double.infinity, 48) : null,
                            ),
                            onPressed: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.blue.shade700,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _range = picked);
                              }
                            },
                            icon: const Icon(Icons.date_range_outlined, size: 18),
                            label: Text(
                              _range == null
                                  ? 'Pick Date Range'
                                  : '${formatDate(_range!.start)} - ${formatDate(_range!.end)}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_range != null && !isMobile)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TextButton(
                                onPressed: () => setState(() => _range = null),
                                child: const Text('Clear'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isMobile) ...[
                      _buildQuickFilterButton('Today', () => setState(() => _range = _todayRange())),
                      _buildQuickFilterButton('This Month', () => setState(() => _range = _monthRange())),
                      _buildQuickFilterButton('This Year', () => setState(() => _range = _yearRange())),
                    ],
                  ],
                ),
                if (isMobile && _range != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _range = null),
                        child: const Text('Clear Date Range'),
                      ),
                    ),
                  ),
                if (isMobile)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickFilterButton('Today', () => setState(() => _range = _todayRange())),
                        _buildQuickFilterButton('This Month', () => setState(() => _range = _monthRange())),
                        _buildQuickFilterButton('This Year', () => setState(() => _range = _yearRange())),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterButton(String label, VoidCallback onPressed) {
    return FilterChip(
      label: Text(label),
      onSelected: (_) => onPressed(),
      selected: false,
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.blue.shade100,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildSummarySection(double totalSales, double totalPurchases, int customerCount, int purchaseCount, double maxWidth) {
    final isMobile = maxWidth < 500;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.summarize_outlined, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Report Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 1 : (maxWidth < 800 ? 2 : 4),
              childAspectRatio: isMobile ? 3 : 1.5,
              crossAxisSpacing: isMobile ? 0 : 16,
              mainAxisSpacing: isMobile ? 12 : 16,
              children: [
                _SummaryCard(
                  title: 'Total Sales',
                  value: formatMoney(totalSales),
                  icon: Icons.trending_up,
                  color: Colors.blue,
                ),
                _SummaryCard(
                  title: 'Total Purchases',
                  value: formatMoney(totalPurchases),
                  icon: Icons.trending_down,
                  color: Colors.orange,
                ),
                _SummaryCard(
                  title: 'Customers',
                  value: customerCount.toString(),
                  icon: Icons.people,
                  color: Colors.purple,
                ),
                _SummaryCard(
                  title: 'Purchases',
                  value: purchaseCount.toString(),
                  icon: Icons.shopping_cart,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerReportSection(List<_CustomerReportRow> customerRows, Map<String, String> unitNames, double maxWidth) {
    final isMobile = maxWidth < 600;
    final isTablet = maxWidth >= 600 && maxWidth < 900;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.people_alt_outlined, color: Colors.orange.shade700),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Customer Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
                      ),
                      onPressed: customerRows.isEmpty
                          ? null
                          : () => _exportCustomerReport(rows: customerRows),
                      icon: Icon(Icons.file_download_outlined, size: isMobile ? 16 : 20),
                      label: isMobile ? const SizedBox() : const Text('Export Excel'),
                    ),
                  ],
                ),
                if (isMobile && customerRows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Swipe horizontally to view all columns',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 0),
          if (customerRows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No customer data for the selected filters.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                  minWidth: isMobile ? maxWidth : double.infinity,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) => Colors.blue.shade50,
                  ),
                  dataRowMaxHeight: 60,
                  columnSpacing: isMobile ? 12 : 16,
                  horizontalMargin: isMobile ? 8 : 12,
                  columns: isMobile || isTablet
                      ? [
                    const DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Sales', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(isTablet ? 'Units' : 'Unit', style: const TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                  ]
                      : const [
                    DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Sales', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Units', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Payments', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: customerRows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(row.phone)),
                        DataCell(Text('${row.province}, ${row.district}')),
                        DataCell(Text(row.salesCount.toString())),
                        DataCell(Text(row.totalQuantity.toStringAsFixed(2))),
                        DataCell(SizedBox(
                          width: isMobile ? 100 : (isTablet ? 120 : 150),
                          child: Text(
                            row.unitBreakdown,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        )),
                        DataCell(Text(formatMoney(row.totalSales))),
                        DataCell(Text(formatMoney(row.totalPayments))),
                        DataCell(
                          Text(
                            formatMoney(row.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: row.balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          if (customerRows.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Customers: ${customerRows.length}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Total Records: ${customerRows.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _emptyProvince = ProvinceData(name: '', districts: []);

class _CustomerReportRow {
  const _CustomerReportRow({
    required this.name,
    required this.phone,
    required this.province,
    required this.district,
    required this.salesCount,
    required this.totalQuantity,
    required this.unitBreakdown,
    required this.totalSales,
    required this.totalPayments,
    required this.balance,
  });

  final String name;
  final String phone;
  final String province;
  final String district;
  final int salesCount;
  final double totalQuantity;
  final String unitBreakdown;
  final double totalSales;
  final double totalPayments;
  final double balance;
}