import 'dart:io';

const _storageFolderName = 'FODEP';
const _storageFileName = 'market_portfolios.json';

Future<String?> readMarketDataPayload() async {
  final file = await _storageFile();
  if (!await file.exists()) return null;
  final content = await file.readAsString();
  return content.trim().isEmpty ? null : content;
}

Future<void> writeMarketDataPayload(String payload) async {
  final file = await _storageFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(payload, flush: true);
}

Future<void> clearMarketDataPayload() async {
  final file = await _storageFile();
  if (await file.exists()) {
    await file.delete();
  }
}

Future<File> _storageFile() async {
  final root = Platform.environment['APPDATA'] ??
      Platform.environment['LOCALAPPDATA'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final directory = Directory(
    [root, _storageFolderName].join(Platform.pathSeparator),
  );
  return File([directory.path, _storageFileName].join(Platform.pathSeparator));
}
