import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

Future<bool> hasInternet() async {
  if (kIsWeb) return true;
  return InternetConnectionChecker().hasConnection;
}

Future<bool> hasInternetConnection(
  List<ConnectivityResult> result,
) async {
  final hasNetwork = result.isNotEmpty &&
      !result.every((entry) => entry == ConnectivityResult.none);
  if (!hasNetwork) return false;
  if (kIsWeb) return true;
  return InternetConnectionChecker().hasConnection;
}
