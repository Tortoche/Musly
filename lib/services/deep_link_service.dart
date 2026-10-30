import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:musly/main.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/screens/player/now_playing_screen.dart';
import 'package:musly/services/haptics_service.dart';
import 'package:musly/services/link_resolver_service.dart';

/// Service interceptant et traitant les liens profonds entrants (musly://, App Links, Intent Send)
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.devid.musly/deep_link');
  bool _initialized = false;
  String? _lastHandledLink;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final link = call.arguments?.toString();
        if (link != null && link.isNotEmpty) {
          await handleLink(link);
        }
      }
    });

    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        // Laisser le temps à l'arbre de widgets et à navigatorKey d'être prêts
        await Future.delayed(const Duration(milliseconds: 700));
        await handleLink(initialLink);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Erreur getInitialLink: $e');
    }
  }

  Future<void> handleLink(String rawLink) async {
    final link = rawLink.trim();
    if (link.isEmpty || link == _lastHandledLink) return;
    _lastHandledLink = link;

    debugPrint('[DeepLinkService] Traitement du lien entrant : $link');
    HapticsService.light();

    try {
      BuildContext? ctx = navigatorKey.currentContext;
      if (ctx == null) {
        for (int i = 0; i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 300));
          ctx = navigatorKey.currentContext;
          if (ctx != null) break;
        }
      }

      final song = await LinkResolverService.resolveLink(link, context: ctx);
      if (song == null) {
        debugPrint(
            '[DeepLinkService] Impossible de résoudre le morceau pour : $link');
        return;
      }

      if (ctx == null) {
        debugPrint('[DeepLinkService] Contexte de navigation indisponible');
        return;
      }

      final playerProvider = Provider.of<PlayerProvider>(ctx, listen: false);
      await playerProvider.playSong(song, playlist: [song], startIndex: 0);
      HapticsService.medium();

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Lecture : ${song.title} — ${song.artist ?? ''}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Ouvrir directement le grand lecteur
      NowPlayingScreen.open(ctx, song: song);
    } catch (e) {
      debugPrint('[DeepLinkService] Erreur lors de la lecture du lien : $e');
    }
  }
}
