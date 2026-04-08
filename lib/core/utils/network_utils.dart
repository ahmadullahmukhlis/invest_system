import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

Future<bool> hasInternet() async {
  return InternetConnectionChecker().hasConnection;
}

Future<bool> hasInternetConnection(
  List<ConnectivityResult> result,
) async {
  final hasNetwork = result.isNotEmpty &&
      !result.every((entry) => entry == ConnectivityResult.none);
  if (!hasNetwork) return false;
  return InternetConnectionChecker().hasConnection;
}
