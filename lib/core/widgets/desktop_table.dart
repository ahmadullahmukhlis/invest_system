import 'package:flutter/material.dart';

class DesktopTable extends StatelessWidget {
  const DesktopTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 900,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: DataTable(
            headingRowHeight: 52,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }
}
