import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geo_data.dart';

final provinceDataProvider = FutureProvider<List<ProvinceData>>((ref) async {
  return loadProvinceData();
});
