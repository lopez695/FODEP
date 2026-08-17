import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Charge un asset image desktop depuis le fichier physique pour rester stable
/// après les hot restarts Windows qui invalident parfois AssetManifest.bin.
class DesktopAssetImage extends StatelessWidget {
  const DesktopAssetImage(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.color,
    this.colorBlendMode,
    this.opacity,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Animation<double>? opacity;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        color: color,
        colorBlendMode: colorBlendMode,
        opacity: opacity,
      );
    }

    final file = _resolveAssetFile(assetPath);
    if (file == null) {
      return SizedBox(width: width, height: height);
    }

    return Image(
      image: FileImage(file),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      color: color,
      colorBlendMode: colorBlendMode,
      opacity: opacity,
    );
  }

  static File? _resolveAssetFile(String assetPath) {
    final normalizedAssetPath =
        assetPath.replaceAll('/', Platform.pathSeparator);
    final executableDir = _parentDirectory(Platform.resolvedExecutable);
    final currentDir = Directory.current.path;
    final candidates = <String>[
      _join(executableDir, 'data', 'flutter_assets', normalizedAssetPath),
      _join(currentDir, normalizedAssetPath),
      _join(currentDir, 'frontend', normalizedAssetPath),
      _join(currentDir, 'data', 'flutter_assets', normalizedAssetPath),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file;
      }
    }

    return null;
  }

  static String _parentDirectory(String path) {
    final separator = Platform.pathSeparator;
    final index = path.lastIndexOf(separator);
    if (index <= 0) {
      return Directory.current.path;
    }
    return path.substring(0, index);
  }

  static String _join(
    String first,
    String second, [
    String? third,
    String? fourth,
  ]) {
    final parts = [
      first,
      second,
      if (third != null) third,
      if (fourth != null) fourth
    ];
    return parts.join(Platform.pathSeparator);
  }
}
