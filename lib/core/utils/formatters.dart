import 'package:intl/intl.dart';

final _currency = NumberFormat('#,##0.00');
final _date = DateFormat('yyyy-MM-dd');

String formatMoney(double value) => _currency.format(value);
String formatDate(DateTime date) => _date.format(date);
