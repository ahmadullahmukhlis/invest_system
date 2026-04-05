import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

const databaseUrl =
    'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app/';

FirebaseDatabase databaseInstance() {
  return FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );
}
