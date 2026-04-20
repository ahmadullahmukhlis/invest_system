import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();
