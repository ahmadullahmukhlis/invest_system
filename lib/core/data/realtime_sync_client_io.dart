import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/firebase_config.dart';

class RealtimeSyncClient {
  RealtimeSyncClient._();

  static final RealtimeSyncClient instance = RealtimeSyncClient._();

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  bool get isConfigured => databaseUrl.trim().isNotEmpty;

  Future<Object?> getJson(String path) async {
    final uri = await _authorizedUriForPath(path);
    debugPrint('[RealtimeSync] GET $path');
    final request = await _httpClient.getUrl(uri);
    request.headers.contentType = ContentType.json;
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    debugPrint(
      '[RealtimeSync] GET $path -> ${response.statusCode} body=${_previewBody(body)}',
    );
    if (response.statusCode == HttpStatus.notFound || body.trim() == 'null') {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == HttpStatus.unauthorized) {
        return _retryGetJson(path);
      }
      throw HttpException(
        'Realtime Database GET failed (${response.statusCode})',
        uri: uri,
      );
    }
    return jsonDecode(body) as Object?;
  }

  Future<void> setJson(String path, Object? value) async {
    final uri = await _authorizedUriForPath(path);
    debugPrint('[RealtimeSync] PUT $path payload=${_previewJson(value)}');
    final request = await _httpClient.putUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(value));
    final response = await request.close();
    debugPrint('[RealtimeSync] PUT $path -> ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == HttpStatus.unauthorized) {
        await _retrySetJson(path, value);
        return;
      }
      throw HttpException(
        'Realtime Database PUT failed (${response.statusCode})',
        uri: uri,
      );
    }
    await response.drain<void>();
  }

  Future<Object?> _retryGetJson(String path) async {
    final uri = await _authorizedUriForPath(path, forceRefreshToken: true);
    debugPrint('[RealtimeSync] GET retry $path');
    final request = await _httpClient.getUrl(uri);
    request.headers.contentType = ContentType.json;
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    debugPrint(
      '[RealtimeSync] GET retry $path -> ${response.statusCode} body=${_previewBody(body)}',
    );
    if (response.statusCode == HttpStatus.notFound || body.trim() == 'null') {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Realtime Database GET failed (${response.statusCode})',
        uri: uri,
      );
    }
    return jsonDecode(body) as Object?;
  }

  Future<void> _retrySetJson(String path, Object? value) async {
    final uri = await _authorizedUriForPath(path, forceRefreshToken: true);
    debugPrint('[RealtimeSync] PUT retry $path payload=${_previewJson(value)}');
    final request = await _httpClient.putUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(value));
    final response = await request.close();
    debugPrint('[RealtimeSync] PUT retry $path -> ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Realtime Database PUT failed (${response.statusCode})',
        uri: uri,
      );
    }
    await response.drain<void>();
  }

  Future<Uri> _authorizedUriForPath(
    String path, {
    bool forceRefreshToken = false,
  }) async {
    final baseUri = _uriForPath(path);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Realtime Database REST sync requires a signed-in user.');
    }
    final token = await user.getIdToken(forceRefreshToken);
    if (token == null || token.isEmpty) {
      throw StateError('Failed to get Firebase auth token for Realtime Database.');
    }
    return baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'auth': token,
      },
    );
  }

  Uri _uriForPath(String path) {
    final normalizedPath = path
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    final suffix = normalizedPath.isEmpty ? '.json' : '$normalizedPath.json';
    return Uri.parse('$databaseUrl$suffix');
  }

  String _previewBody(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 200) {
      return normalized;
    }
    return '${normalized.substring(0, 200)}...';
  }

  String _previewJson(Object? value) {
    final encoded = jsonEncode(value);
    if (encoded.length <= 200) {
      return encoded;
    }
    return '${encoded.substring(0, 200)}...';
  }
}
