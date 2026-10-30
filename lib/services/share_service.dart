import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:musly/models/song.dart';
import 'package:musly/services/haptics_service.dart';

/// Service gérant le partage public des morceaux avec liens riches.
class ShareService {
  static const String _baseShareUrl = 'https://music.corentinjanin.fr/track';

  /// Construit l'URL publique de partage pour un morceau
  static String getShareUrl(Song song) {
    return '$_baseShareUrl/${song.id}';
  }

  /// Partage le morceau via la feuille de partage native du système
  static Future<void> shareSong(BuildContext context, Song song) async {
    HapticsService.light();
    final url = getShareUrl(song);
    final artistName = (song.artist != null && song.artist!.isNotEmpty)
        ? song.artist!
        : 'Musly';
    final shareText = '🎵 ${song.title} — $artistName\n$url';

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? (box.localToGlobal(Offset.zero) & box.size)
            : const Rect.fromLTWH(0, 0, 100, 100);

        await Share.share(
          shareText,
          subject: '${song.title} — $artistName',
          sharePositionOrigin: origin,
        );
        return;
      }
    } catch (e) {
      debugPrint('[ShareService] Erreur partage natif: $e');
    }

    // Fallback presse-papier pour Desktop ou en cas d'erreur
    try {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lien copié dans le presse-papier : $url'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }
}
