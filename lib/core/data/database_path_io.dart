import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> localDatabasePath(String fileName) async {
  final supportDirectory = await getApplicationSupportDirectory();
  final databaseDirectory = await supportDirectory.create(recursive: true);
  return p.join(databaseDirectory.path, fileName);
}
