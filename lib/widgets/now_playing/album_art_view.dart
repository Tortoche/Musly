import 'dart:io';
import 'package:flutter/material.dart';
import 'package:musly/models/song.dart';
import 'package:musly/services/player_ui_settings_service.dart';
import 'package:musly/services/offline_service.dart';
import 'package:musly/widgets/common/album_artwork.dart';

class AlbumArtView extends StatelessWidget {
  final ImageProvider? image;
  final Song? song;
  final String? coverArt;
  final String tag;
  final double? borderRadius;
  final Color? dominantColor;

  const AlbumArtView({
    super.key,
    this.image,
    this.song,
    this.coverArt,
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

        final String? effectiveCoverArt = coverArt ?? song?.coverArt;

        Widget artWidget;
        if (effectiveCoverArt != null && effectiveCoverArt.isNotEmpty) {
          artWidget = AlbumArtwork(
            coverArt: effectiveCoverArt,
            size: double.infinity,
            borderRadius: effectiveRadius,
            shadow: const BoxShadow(color: Colors.transparent),
          );
        } else if (song != null &&
            OfflineService().isSongDownloaded(song!.id)) {
          final offlinePath = OfflineService().getLocalCoverArtPath(song!.id);
          if (offlinePath != null && File(offlinePath).existsSync()) {
            artWidget = ClipRRect(
              borderRadius: BorderRadius.circular(effectiveRadius),
              child: Image.file(
                File(offlinePath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              ),
            );
          } else if (image != null) {
            artWidget = ClipRRect(
              borderRadius: BorderRadius.circular(effectiveRadius),
              child: Image(
                image: image!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              ),
            );
          } else {
            artWidget = _buildPlaceholder();
          }
        } else if (image != null) {
          artWidget = ClipRRect(
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: Image(
              image: image!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            ),
          );
        } else {
          artWidget = _buildPlaceholder();
        }

        return Center(
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
                      color: dominantColor!.withValues(alpha: 0.45),
                      blurRadius: 40.0,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 36.0,
                    spreadRadius: -2,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: artWidget,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF141418),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 72,
          color: Colors.white38,
        ),
      ),
    );
  }
}
