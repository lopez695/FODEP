import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'desktop_asset_image.dart';

/// Widget qui affiche le logo principal de l'outil.
class RwaToolLogo extends StatelessWidget {
  const RwaToolLogo({
    super.key,
    this.size = 40,
  });

  static const String _assetPath = 'assets/images/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: DesktopAssetImage(
        _assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
