import 'dart:io' as io;

String? runtimeEnvironmentValue(String key) => io.Platform.environment[key];
