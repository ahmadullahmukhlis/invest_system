import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String?> savePdfToDownloads({
  required BuildContext context,
  required Uint8List bytes,
  required String fileName,
}) async {
  if (Platform.isAndroid) {
    final status = await (await Permission.manageExternalStorage.request());
    if (!status.isGranted) {
      final legacy = await Permission.storage.request();
      if (!legacy.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied.')),
          );
        }
        return null;
      }
    }
  }

  final dir = Directory('/storage/emulated/0/Download');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> saveFileToInvestmentDocuments({
  required Uint8List bytes,
  required String fileName,
}) async {
  final Directory dir;
  if (Platform.isAndroid) {
    final status = await (await Permission.manageExternalStorage.request());
    if (!status.isGranted) {
      final legacy = await Permission.storage.request();
      if (!legacy.isGranted) {
        throw const FileSystemException('Storage permission denied');
      }
    }
    dir = Directory('/storage/emulated/0/Documents/Investment');
  } else {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final baseDirectory = documentsDirectory.parent;
    dir = Directory(p.join(baseDirectory.path, 'Investment'));
  }

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
