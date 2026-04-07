import 'dart:convert';

import 'package:flutter/services.dart';

class ProvinceData {
  const ProvinceData({
    required this.name,
    required this.districts,
  });

  final String name;
  final List<String> districts;
}

Future<List<ProvinceData>> loadProvinceData() async {
  String raw;
  try {
    raw = await rootBundle.loadString('assets/provinces-and-districts.json');
  } catch (_) {
    return const [];
  }
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  final provinces = <ProvinceData>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final name = (item['namePa'] as String?)?.trim() ??
        (item['name'] as String?)?.trim() ??
        '';
    if (name.isEmpty) continue;
    final districtsRaw = item['districts'];
    final districts = <String>[];
    if (districtsRaw is List) {
      for (final district in districtsRaw) {
        if (district is! Map) continue;
        final districtName = (district['namePa'] as String?)?.trim() ??
            (district['name'] as String?)?.trim() ??
            '';
        if (districtName.isNotEmpty) {
          districts.add(districtName);
        }
      }
    }
    provinces.add(ProvinceData(name: name, districts: districts));
  }
  provinces.sort((a, b) => a.name.compareTo(b.name));
  return provinces;
}
