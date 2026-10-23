import 'package:flutter/material.dart';
import 'package:musly/services/player_ui_settings_service.dart';

class AlbumArtView extends StatelessWidget {
  final ImageProvider image;
  final String tag;
  final double? borderRadius;
  final Color? dominantColor;

  const AlbumArtView({
    super.key,
    required this.image,
    required this.tag,
    this.borderRadius,
    this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    final uiSettings = PlayerUiSettingsService();
    return ValueListenableBuilder<String>(
      valueListenable: uiSettings.artworkShapeNotifier,
      builder: (context, shape, _) {
        final double effectiveRadius = shape == 'circle'
            ? 9999.0
            : (borderRadius ?? (shape == 'square' ? 0.0 : 16.0));

        return Hero(
          tag: tag,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(effectiveRadius),
                  boxShadow: [
                    if (dominantColor != null &&
                        dominantColor != Colors.black &&
                        dominantColor != Colors.white)
                      BoxShadow(
                        color: dominantColor!.withValues(alpha: 0.4),
                        blurRadius: 36.0,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 32.0,
                      spreadRadius: -2,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16.0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(effectiveRadius),
                  child: Image(
                    image: image,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 250,
                      height: 250,
                      color: Colors.grey[850],
                      child: const Icon(Icons.music_note_rounded,
                          size: 64, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
