import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sous-titre de carte KPI, toujours tenu sur une seule ligne.
///
/// Un texte trop long n'est ni replié sur une seconde ligne ni rétréci : il
/// garde sa taille et défile horizontalement au survol de la carte, puis
/// revient à sa position de départ dès que le pointeur en sort. Au repos, ses
/// extrémités masquées sont estompées pour signaler qu'il reste à lire.
class HoverScrollText extends StatefulWidget {
  const HoverScrollText({
    super.key,
    required this.text,
    required this.style,
    required this.hovered,
  });

  final String text;
  final TextStyle style;

  /// Survol de la carte entière, pas seulement du texte : c'est la carte qui
  /// porte le `MouseRegion`.
  final bool hovered;

  @override
  State<HoverScrollText> createState() => _HoverScrollTextState();
}

class _HoverScrollTextState extends State<HoverScrollText>
    with SingleTickerProviderStateMixin {
  /// Vitesse de défilement, en pixels par seconde : assez lente pour rester
  /// lisible dans une rangée de tuiles.
  static const double _pixelsPerSecond = 34;

  /// Hauteur réservée au sous-titre, identique qu'il défile ou non, pour que
  /// les cartes de la rangée gardent la même ligne de base.
  static const double _lineHeight = 12;

  /// Largeur du dégradé d'estompage aux extrémités.
  static const double _fadeWidth = 10;

  late final AnimationController _controller;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(HoverScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hovered != oldWidget.hovered || widget.text != oldWidget.text) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (widget.hovered && _overflow > 0.5) {
      // Aller-retour continu tant que le pointeur reste sur la carte. La durée
      // suit la longueur cachée : un texte à peine tronqué ne part pas dans un
      // long voyage.
      _controller.duration = Duration(
        milliseconds:
            (_overflow / _pixelsPerSecond * 1000).round().clamp(600, 6000),
      );
      _controller.repeat(reverse: true);
      return;
    }
    _controller.stop();
    if (_controller.value > 0) {
      // Le retour est monotone : la valeur du contrôleur pilote directement la
      // position, le texte ne repart donc jamais vers l'avant en sortie.
      _controller.animateBack(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final textWidth = painter.size.width;
        final available = constraints.maxWidth;
        final overflow = math.max(0.0, textWidth - available);

        if ((overflow - _overflow).abs() > 0.5) {
          _overflow = overflow;
          // La mesure a lieu pendant la disposition : on repousse le pilotage
          // de l'animation après la frame en cours.
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncAnimation());
        }

        final line = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: widget.style,
        );

        if (overflow <= 0.5) {
          return SizedBox(
            height: _lineHeight,
            child: Align(alignment: Alignment.centerLeft, child: line),
          );
        }

        return SizedBox(
          height: _lineHeight,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = Curves.easeInOut.transform(_controller.value);
              final dx = -overflow * progress;
              final fadeStop =
                  (_fadeWidth / math.max(1.0, available)).clamp(0.0, 0.4);
              final fadeLeft = dx < -0.5;
              final fadeRight = dx > -(overflow - 0.5);

              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    fadeLeft ? Colors.transparent : Colors.white,
                    Colors.white,
                    Colors.white,
                    fadeRight ? Colors.transparent : Colors.white,
                  ],
                  stops: [
                    0,
                    fadeLeft ? fadeStop : 0,
                    fadeRight ? 1 - fadeStop : 1,
                    1,
                  ],
                ).createShader(bounds),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: textWidth,
                    maxWidth: textWidth,
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: line,
          ),
        );
      },
    );
  }
}
