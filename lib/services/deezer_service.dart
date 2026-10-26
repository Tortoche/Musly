import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';

class DeezerService {
  static final DeezerService _instance = DeezerService._internal();
  factory DeezerService() => _instance;
  DeezerService._internal();

  static const String _baseUrl = 'https://api.deezer.com';

  /// Recherche directe de pistes sur Deezer avec pochettes HD 1000x1000
  Future<List<Song>> searchTracks(String query, {int limit = 35}) async {
    if (query.trim().length < 2) return [];
    final url = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}&limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((t) {
          final id = t['id']?.toString() ?? '';
          final albumData = t['album'] as Map<String, dynamic>?;
          final artistData = t['artist'] as Map<String, dynamic>?;
          final coverUrl = albumData?['cover_xl'] ??
              albumData?['cover_big'] ??
              albumData?['cover_medium'] ??
              '';

          return Song(
            id: id.startsWith('ext_dz_') ? id : 'ext_dz_$id',
            title: t['title'] ?? '',
            artist: artistData?['name'] ?? 'Artiste inconnu',
            artistId: artistData?['id']?.toString(),
            album: albumData?['title'] ?? '',
            albumId: albumData?['id']?.toString(),
            coverArt: coverUrl.isNotEmpty ? coverUrl : null,
            duration: (t['duration'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur searchTracks: $e');
    }
    return [];
  }

  /// Recherche d'artistes sur Deezer
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    if (query.trim().length < 2) return [];
    final url = Uri.parse('$_baseUrl/search/artist?q=${Uri.encodeComponent(query)}&limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((a) {
          final id = a['id']?.toString() ?? '';
          final picture = a['picture_xl'] ?? a['picture_big'] ?? a['picture_medium'];
          return Artist(
            id: id,
            name: a['name'] ?? 'Artiste inconnu',
            coverArt: picture,
            artistImageUrl: picture,
            albumCount: (a['nb_album'] as num?)?.toInt(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur searchArtists: $e');
    }
    return [];
  }

  /// Récupérer les détails d'un artiste sur Deezer
  Future<Artist?> getArtist(String artistId) async {
    if (artistId.isEmpty) return null;
    final cleanId = artistId.replaceAll('ext_dz_', '').replaceAll('ar-', '');
    final url = Uri.parse('$_baseUrl/artist/$cleanId');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['error'] != null) return null;
        final picture = data['picture_xl'] ?? data['picture_big'] ?? data['picture_medium'];
        return Artist(
          id: data['id']?.toString() ?? cleanId,
          name: data['name'] ?? 'Artiste inconnu',
          coverArt: picture,
          artistImageUrl: picture,
          albumCount: (data['nb_album'] as num?)?.toInt(),
        );
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur getArtist: $e');
    }
    return null;
  }

  /// Récupérer les 50 meilleurs morceaux d'un artiste sur Deezer
  Future<List<Song>> getArtistTopTracks(String artistId, {int limit = 50}) async {
    if (artistId.isEmpty) return [];
    final cleanId = artistId.replaceAll('ext_dz_', '').replaceAll('ar-', '');
    final url = Uri.parse('$_baseUrl/artist/$cleanId/top?limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((t) {
          final id = t['id']?.toString() ?? '';
          final albumData = t['album'] as Map<String, dynamic>?;
          final artistData = t['artist'] as Map<String, dynamic>?;
          final coverUrl = albumData?['cover_xl'] ??
              albumData?['cover_big'] ??
              albumData?['cover_medium'] ??
              '';

          return Song(
            id: id.startsWith('ext_dz_') ? id : 'ext_dz_$id',
            title: t['title'] ?? '',
            artist: artistData?['name'] ?? 'Artiste inconnu',
            artistId: artistData?['id']?.toString(),
            album: albumData?['title'] ?? '',
            albumId: albumData?['id']?.toString(),
            coverArt: coverUrl.isNotEmpty ? coverUrl : null,
            duration: (t['duration'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur getArtistTopTracks: $e');
    }
    return [];
  }

  /// Récupérer les vrais albums d'un artiste sur Deezer (exclut strictement les singles)
  Future<List<Album>> getArtistAlbums(String artistId, {int limit = 50}) async {
    if (artistId.isEmpty) return [];
    final cleanId = artistId.replaceAll('ext_dz_', '').replaceAll('ar-', '');
    final url = Uri.parse('$_baseUrl/artist/$cleanId/albums?limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list
            .where((alb) {
              final recordType = alb['record_type']?.toString().toLowerCase();
              // STRICTEMENT les vrais albums : on ignore les singles (qui n'ont qu'un morceau)
              return recordType != 'single';
            })
            .map((alb) {
              final id = alb['id']?.toString() ?? '';
              final cover = alb['cover_xl'] ?? alb['cover_big'] ?? alb['cover_medium'];
              final nbTracks = (alb['nb_tracks'] as num?)?.toInt() ?? 10;

              return Album(
                id: id.startsWith('ext_dz_') ? id : 'ext_dz_$id',
                name: alb['title'] ?? '',
                coverArt: cover,
                songCount: nbTracks,
                year: int.tryParse(alb['release_date']?.toString().split('-').first ?? ''),
              );
            })
            .toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur getArtistAlbums: $e');
    }
    return [];
  }

  /// Récupérer les détails d'un album sur Deezer
  Future<Album?> getAlbum(String albumId) async {
    if (albumId.isEmpty) return null;
    final cleanId = albumId.replaceAll('ext_dz_', '').replaceAll('al-', '');
    final url = Uri.parse('$_baseUrl/album/$cleanId');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['error'] != null) return null;
        final cover = data['cover_xl'] ?? data['cover_big'] ?? data['cover_medium'];
        final artistData = data['artist'] as Map<String, dynamic>?;
        final nbTracks = (data['nb_tracks'] as num?)?.toInt() ?? (data['tracks']?['data'] as List?)?.length;

        return Album(
          id: cleanId.startsWith('ext_dz_') ? cleanId : 'ext_dz_$cleanId',
          name: data['title'] ?? '',
          artist: artistData?['name'],
          artistId: artistData?['id']?.toString(),
          coverArt: cover,
          songCount: nbTracks,
          year: int.tryParse(data['release_date']?.toString().split('-').first ?? ''),
        );
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur getAlbum: $e');
    }
    return null;
  }

  /// Récupérer tous les morceaux d'un album depuis Deezer (Full Album Universel)
  Future<List<Song>> getAlbumTracks(String albumId, {String? defaultCover, String? defaultArtist}) async {
    if (albumId.isEmpty) return [];
    final cleanId = albumId.replaceAll('ext_dz_', '').replaceAll('al-', '');
    final url = Uri.parse('$_baseUrl/album/$cleanId/tracks?limit=100');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((t) {
          final id = t['id']?.toString() ?? '';
          final artistData = t['artist'] as Map<String, dynamic>?;
          return Song(
            id: id.startsWith('ext_dz_') ? id : 'ext_dz_$id',
            title: t['title'] ?? '',
            artist: artistData?['name'] ?? defaultArtist ?? 'Artiste inconnu',
            artistId: artistData?['id']?.toString(),
            albumId: cleanId.startsWith('ext_dz_') ? cleanId : 'ext_dz_$cleanId',
            coverArt: defaultCover,
            duration: (t['duration'] as num?)?.toInt() ?? 0,
            track: (t['track_position'] as num?)?.toInt(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur getAlbumTracks: $e');
    }
    return [];
  }

  /// Recherche d'albums sur Deezer
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async {
    if (query.trim().length < 2) return [];
    final url = Uri.parse('$_baseUrl/search/album?q=${Uri.encodeComponent(query)}&limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((alb) {
          final id = alb['id']?.toString() ?? '';
          final cover = alb['cover_xl'] ?? alb['cover_big'] ?? alb['cover_medium'];
          final artistData = alb['artist'] as Map<String, dynamic>?;
          return Album(
            id: id,
            name: alb['title'] ?? '',
            artist: artistData?['name'],
            artistId: artistData?['id']?.toString(),
            coverArt: cover,
            songCount: (alb['nb_tracks'] as num?)?.toInt(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur searchAlbums: $e');
    }
    return [];
  }

  /// Recherche d'un artiste par son nom sur Deezer
  Future<Artist?> searchArtistByName(String name) async {
    if (name.trim().isEmpty) return null;
    final url = Uri.parse('$_baseUrl/search/artist?q=${Uri.encodeComponent(name)}&limit=1');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        if (list.isNotEmpty) {
          final art = list.first;
          final id = art['id']?.toString() ?? '';
          final cover = art['picture_xl'] ?? art['picture_big'] ?? art['picture_medium'];
          return Artist(
            id: id,
            name: art['name'] ?? name,
            coverArt: cover,
            artistImageUrl: cover,
            albumCount: (art['nb_album'] as num?)?.toInt(),
          );
        }
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur searchArtistByName: $e');
    }
    return null;
  }

  /// Tops & Tendances du Jour (Deezer Charts)
  Future<List<Song>> getChartTracks({int limit = 30}) async {
    final url = Uri.parse('$_baseUrl/chart/0/tracks?limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((t) {
          final id = t['id']?.toString() ?? '';
          final albumData = t['album'] as Map<String, dynamic>?;
          final artistData = t['artist'] as Map<String, dynamic>?;
          final coverUrl = albumData?['cover_xl'] ??
              albumData?['cover_big'] ??
              albumData?['cover_medium'] ??
              '';

          return Song(
            id: id.startsWith('ext_dz_') ? id : 'ext_dz_$id',
            title: t['title'] ?? '',
            artist: artistData?['name'] ?? 'Artiste inconnu',
            artistId: artistData?['id']?.toString(),
            album: albumData?['title'] ?? '',
            albumId: albumData?['id']?.toString(),
            coverArt: coverUrl.isNotEmpty ? coverUrl : null,
            duration: (t['duration'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur getChartTracks: $e');
    }
    return [];
  }

  /// Autoplay Radio « Même Style » (Deezer)
  Future<List<Song>> fetchSimilarArtistTracks(String artistId, {int limit = 10}) async {
    if (artistId.isEmpty) return [];
    final cleanId = artistId.replaceAll('ext_dz_', '').replaceAll('ar-', '');
    final url = Uri.parse('$_baseUrl/artist/$cleanId/radio?limit=$limit');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((t) {
          final id = t['id']?.toString() ?? '';
          final albumData = t['album'] as Map<String, dynamic>?;
          final artistData = t['artist'] as Map<String, dynamic>?;
          final coverUrl = albumData?['cover_xl'] ??
              albumData?['cover_big'] ??
              albumData?['cover_medium'] ??
              '';

          return Song(
            id: id.startsWith('ext_dz_') ? id : 'ext_dz_$id',
            title: t['title'] ?? '',
            artist: artistData?['name'] ?? 'Artiste inconnu',
            artistId: artistData?['id']?.toString(),
            album: albumData?['title'] ?? '',
            albumId: albumData?['id']?.toString(),
            coverArt: coverUrl.isNotEmpty ? coverUrl : null,
            duration: (t['duration'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[DeezerService] Erreur Autoplay Radio: $e');
    }
    return [];
  }
}
