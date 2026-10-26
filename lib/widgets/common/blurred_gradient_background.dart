import 'package:flutter/material.dart';

class BlurredGradientBackground extends StatelessWidget {
  final List<Color> colors;
  final Widget child;

  const BlurredGradientBackground({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasColor = colors.isNotEmpty &&
        colors.first != Colors.black &&
        colors.first.computeLuminance() > 0.01;

    final primaryGlow = hasColor ? colors.first : const Color(0xFF141418);
    final secondaryGlow = (colors.length > 1 && colors[1] != Colors.black)
        ? colors[1]
        : primaryGlow;

    return Stack(
      children: [
        // Pure black OLED base
        const Positioned.fill(
          child: ColoredBox(color: Colors.black),
        ),

        // Elegant subtle ambient radial glow behind the artwork
        if (hasColor) ...[
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            height: 480,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.4),
                    radius: 1.1,
                    colors: [
                      primaryGlow.withValues(alpha: 0.38),
                      secondaryGlow.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        RepaintBoundary(
          child: child,
        ),
      ],
    );
  }
}
