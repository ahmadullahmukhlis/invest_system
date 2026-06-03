class RealtimeSyncClient {
  RealtimeSyncClient._();

  static final RealtimeSyncClient instance = RealtimeSyncClient._();

  bool get isConfigured => false;

  Future<Object?> getJson(String path) async => null;

  Future<void> setJson(String path, Object? value) async {}
}
