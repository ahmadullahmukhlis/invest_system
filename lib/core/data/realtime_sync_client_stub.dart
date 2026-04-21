class RealtimeSyncClient {
  RealtimeSyncClient._();

  static final RealtimeSyncClient instance = RealtimeSyncClient._();

  bool get isConfigured => false;

  Future<Object?> getJson(String path) async {
    throw UnsupportedError('Realtime sync is not available on this platform.');
  }

  Future<void> setJson(String path, Object? value) async {
    throw UnsupportedError('Realtime sync is not available on this platform.');
  }
}
