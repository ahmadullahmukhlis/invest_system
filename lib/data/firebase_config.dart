import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

const databaseUrl =
    'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app/';

bool get useRealtimeDatabaseRestFallback =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

FirebaseDatabase databaseInstance() {
  return FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );
}

FirebaseDatabase? databaseInstanceOrNull() {
  if (useRealtimeDatabaseRestFallback) {
    return null;
  }
  return databaseInstance();
}
