Future<String?> readMarketDataPayload() async => null;

Future<void> writeMarketDataPayload(String payload) async {
  throw UnsupportedError('File storage is not available on this platform.');
}

Future<void> clearMarketDataPayload() async {}
