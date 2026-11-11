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

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return Stack(
      children: [
        // Pure black OLED base
        const Positioned.fill(
          child: ColoredBox(color: Colors.black),
        ),

        // Elegant subtle ambient radial glow behind the artwork
        if (hasColor) ...[
          // Fullscreen primary ambient glow - dynamically centered behind the artwork
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: isLandscape
                        ? const Alignment(-0.52, -0.05)
                        : const Alignment(0.0, -0.42),
                    radius: isLandscape ? 1.35 : 1.05,
                    colors: [
                      primaryGlow.withValues(alpha: isLandscape ? 0.45 : 0.38),
                      secondaryGlow.withValues(alpha: isLandscape ? 0.22 : 0.18),
                      primaryGlow.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 0.80, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Secondary soft ambient glow for smooth depth in landscape
          if (isLandscape)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, 0.35),
                      radius: 1.1,
                      colors: [
                        secondaryGlow.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // Smooth OLED vignette overlay - ensures flawless, seamless blend with black
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isLandscape
                      ? LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.40, 0.78, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 0.75, 1.0],
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

          // Edge softening vignette for desktop landscape
          if (isLandscape)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.10, 0.90, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.50),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.60),
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
