import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../models/models.dart';

import '../services/audio_handler.dart';

import '../services/local_music_service.dart';

import '../services/services.dart';

import '../services/discovery_service.dart';

import '../widgets/common/album_artwork.dart';



class LibraryProvider extends ChangeNotifier

    implements AndroidAutoLibraryDelegate {

  final SubsonicService _subsonicService;

  final MuslyAudioHandler _audioHandler;



  bool _localOnlyMode = false;

  bool _serverOfflineMode = false;

  bool _mergeLocalLibrary = false;

  LocalMusicService? _localMusicService;

  final LibraryDatabaseService _db = LibraryDatabaseService();



  List<Artist> _artists = [];

  List<Album> _recentAlbums = [];

  List<Album> _frequentAlbums = [];

  List<Album> _newestAlbums = [];

  List<Album> _randomAlbums = [];

  List<Playlist> _playlists = [];

  List<Song> _randomSongs = [];

  List<String> _genres = [];

  List<Genre> _richGenres = [];

  SearchResult? _starred;



  List<Album> _cachedAllAlbums = [];

  List<Song> _cachedAllSongs = [];

  List<Playlist> _cachedPlaylists = [];

  DateTime? _lastCacheUpdate;



  bool _isLoading = false;

  bool _isBackgroundSyncing = false;

  Future<void>? _syncFuture;

  bool _isInitialized = false;

  String? _error;



  static const String _playlistsCacheKey = 'cached_playlists';

  static const String _artistsCacheKey = 'cached_artists';

  static const String _lastUpdateKey = 'last_cache_update';



  LibraryProvider(this._subsonicService, this._audioHandler);



  SubsonicService get subsonicService => _subsonicService;

  bool get isLocalOnlyMode => _localOnlyMode;

  bool get isServerOfflineMode => _serverOfflineMode;

  bool get mergeLocalLibrary => _mergeLocalLibrary;

  List<Album> get recentAlbums => _recentAlbums;

  List<Album> get frequentAlbums => _frequentAlbums;

  List<Album> get newestAlbums => _newestAlbums;

  List<Album> get randomAlbums => _randomAlbums;

  List<Playlist> get playlists => _playlists;

  List<Song> get randomSongs => _randomSongs;

  List<String> get genres => _genres;

  List<Genre> get richGenres => _richGenres;

  SearchResult? get starred => _starred;

  bool get isLoading => _isLoading;

  bool get isBackgroundSyncing => _isBackgroundSyncing;

  bool get isInitialized => _isInitialized;

  String? get error => _error;



  void setLocalMusicService(

    LocalMusicService service, {

    bool mergeWithServer = false,

  }) {

    _localMusicService?.removeListener(_onLocalMusicServiceChanged);

    _localMusicService = service;

    _localOnlyMode = !mergeWithServer;

    _mergeLocalLibrary = mergeWithServer;

    _isInitialized = false;

    service.addListener(_onLocalMusicServiceChanged);

    if (mergeWithServer) {

      _onLocalMusicServiceChanged();

    }

  }



  void _onLocalMusicServiceChanged() {

    if (_localMusicService == null || _localMusicService!.isScanning) return;



    if (_localOnlyMode) {

      _cachedAllSongs = List.from(_localMusicService!.songs);

      _cachedAllAlbums = List.from(_localMusicService!.albums);

      _artists = List.from(_localMusicService!.artists);

      _randomSongs = _cachedAllSongs.take(50).toList();

      _recentAlbums = _cachedAllAlbums.take(20).toList();

      _isInitialized = true;

      _isLoading = false;

      notifyListeners();

    } else if (_mergeLocalLibrary) {

      notifyListeners();

    }

  }



  void setMergeLocalLibrary(bool enabled) {

    if (_mergeLocalLibrary == enabled) return;

    _mergeLocalLibrary = enabled;

    notifyListeners();

  }



  void setLocalOnlyMode(bool enabled) {

    if (!enabled && _localOnlyMode) {

      _localMusicService?.removeListener(_onLocalMusicServiceChanged);

      _localMusicService = null;

      _cachedAllSongs = [];

      _cachedAllAlbums = [];

      _artists = [];

      _randomSongs = [];

      _recentAlbums = [];

      _playlists = [];

      _cachedPlaylists = [];

    }

    _localOnlyMode = enabled;

    _isInitialized = false;

    notifyListeners();

  }



  void setServerOfflineMode(bool offline) {

    _serverOfflineMode = offline;

  }



  List<Album>? _mergedAlbumsCache;

  List<Song>? _mergedSongsCache;

  List<Artist>? _mergedArtistsCache;



  void _invalidateMergedCache() {

    _mergedAlbumsCache = null;

    _mergedSongsCache = null;

    _mergedArtistsCache = null;

  }



  @override

  void notifyListeners() {

    _invalidateMergedCache();

    super.notifyListeners();

  }



  @override

  String getCoverArtUrl(String? coverArt) {

    return _subsonicService.getCoverArtUrl(coverArt, size: 600);

  }



  @override

  List<Album> get cachedAllAlbums {

    if (!_mergeLocalLibrary ||

        _localMusicService == null ||

        _localMusicService!.isEmpty) {

      return _cachedAllAlbums;

    }

    if (_mergedAlbumsCache != null) return _mergedAlbumsCache!;

    final localAlbums = _localMusicService!.albums;

    final serverIds = _cachedAllAlbums.map((album) => album.id).toSet();

    _mergedAlbumsCache = [

      ..._cachedAllAlbums,

      ...localAlbums.where((album) => !serverIds.contains(album.id)),

    ];

    return _mergedAlbumsCache!;

  }



  @override

  List<Song> get cachedAllSongs {

    if (!_mergeLocalLibrary ||

        _localMusicService == null ||

        _localMusicService!.isEmpty) {

      return _cachedAllSongs;

    }

    if (_mergedSongsCache != null) return _mergedSongsCache!;

    final localSongs = _localMusicService!.songs;

    final serverIds = _cachedAllSongs.map((song) => song.id).toSet();

    _mergedSongsCache = [

      ..._cachedAllSongs,

      ...localSongs.where((song) => !serverIds.contains(song.id)),

    ];

    return _mergedSongsCache!;

  }



  @override

  List<Artist> get artists {

    if (!_mergeLocalLibrary ||

        _localMusicService == null ||

        _localMusicService!.isEmpty) {

      return _artists;

    }

    if (_mergedArtistsCache != null) return _mergedArtistsCache!;

    final localArtists = _localMusicService!.artists;

    final serverIds = _artists.map((artist) => artist.id).toSet();

    _mergedArtistsCache = [

      ..._artists,

      ...localArtists.where((artist) => !serverIds.contains(artist.id)),

    ];

    return _mergedArtistsCache!;

  }



  Future<void> initialize() async {

    if (_isInitialized) return;



    _isLoading = true;

    _error = null;

    notifyListeners();



    try {

      if (_localOnlyMode && _localMusicService != null) {

        _cachedAllSongs = List.from(_localMusicService!.songs);

        _cachedAllAlbums = List.from(_localMusicService!.albums);

        _artists = List.from(_localMusicService!.artists);

        _randomSongs = _cachedAllSongs.take(50).toList();

        _recentAlbums = _cachedAllAlbums.take(20).toList();

        _isInitialized = true;

        _isLoading = false;

        notifyListeners();

        return;

      }



      await _loadCachedData(loadFullLibrary: true);



      if (_recentAlbums.isEmpty && _cachedAllAlbums.isNotEmpty) {

        _recentAlbums = _cachedAllAlbums.take(20).toList();

      }

      if (_randomSongs.isEmpty && _cachedAllSongs.isNotEmpty) {

        _randomSongs = _cachedAllSongs.take(50).toList();

      }

      if (_playlists.isEmpty && _cachedPlaylists.isNotEmpty) {

        _playlists = _cachedPlaylists;

      }



      _audioHandler.notifyAutoChildrenChanged();



      if (!_serverOfflineMode) {

        try {

          await Future.wait([

            loadRecentAlbums(),

            loadRandomSongs(),

            loadPlaylists(),

            loadArtists(),

          ]).timeout(

            const Duration(seconds: 5),

            onTimeout: () => throw TimeoutException('Server not responding'),

          );

        } catch (_) {}

      }



      _isInitialized = true;

      _preloadCoverArt();

      _scheduleBackgroundRefresh();

    } catch (e) {

      _error = e.toString();

    } finally {

      _isLoading = false;

      notifyListeners();

    }

  }



  Future<void> ensureLibraryLoaded() async {

    if (_localOnlyMode && _localMusicService != null) {

      _cachedAllSongs = List.from(_localMusicService!.songs);

      _cachedAllAlbums = List.from(_localMusicService!.albums);

      _artists = List.from(_localMusicService!.artists);

      _randomSongs = _cachedAllSongs.take(50).toList();

      _recentAlbums = _cachedAllAlbums.take(20).toList();

      notifyListeners();

      return;

    }



    if (_subsonicService.isYoutube || _serverOfflineMode) return;



    if (_cachedAllAlbums.isNotEmpty && _cachedAllSongs.isNotEmpty) return;



    if (_isBackgroundSyncing && _syncFuture != null) {

      await _syncFuture;

      return;

    }



    _isLoading = true;

    notifyListeners();



    try {

      await _loadCachedData(loadFullLibrary: true);



      if (_cachedAllAlbums.isEmpty || _cachedAllSongs.isEmpty) {

        _syncFuture = _refreshAllDataInBackground();

        await _syncFuture;

      }

    } finally {

      _isLoading = false;

      notifyListeners();

    }

  }



  Future<void> _loadCachedData({bool loadFullLibrary = false}) async {

    try {

      final prefs = await SharedPreferences.getInstance();



      final playlistsJson = prefs.getString(_playlistsCacheKey);

      if (playlistsJson != null) {

        final List<dynamic> playlistsList = json.decode(playlistsJson);

        _cachedPlaylists = playlistsList

            .map((playlistMap) =>

                Playlist.fromJson(playlistMap as Map<String, dynamic>))

            .toList();

        _playlists = _cachedPlaylists;

      }



      if (_subsonicService.isYoutube) {

        _cachedAllAlbums = [];

        _cachedAllSongs = await _db.getAllSongs();

        _cachedPlaylists = await _subsonicService.getPlaylists();

        _playlists = _cachedPlaylists;



        final songMap = {for (final song in _cachedAllSongs) song.id: song};

        for (final playlist in _playlists) {

          if (playlist.songs != null) {

            for (final song in playlist.songs!) {

              songMap[song.id] = song;

            }

          }

        }

        _cachedAllSongs = songMap.values.toList();



        final artistMap = <String, int>{};

        for (final song in _cachedAllSongs) {

          if (song.artist != null &&

              song.artist!.isNotEmpty &&

              song.artist != 'Unknown') {

            artistMap[song.artist!] = (artistMap[song.artist!] ?? 0) + 1;

          }

        }

        _artists = artistMap.keys

            .map((name) => Artist(id: 'yt-$name', name: name))

            .toList();



        if (_randomSongs.isEmpty && _cachedAllSongs.isNotEmpty) {

          _randomSongs = _cachedAllSongs.take(50).toList();

        } else if (_cachedAllSongs.isEmpty) {

          Future.microtask(() => loadRandomSongs());

        }

        return;

      }



      final artistsJson = prefs.getString(_artistsCacheKey);

      if (artistsJson != null) {

        final List<dynamic> artistsList = json.decode(artistsJson);

        _artists = artistsList

            .map((artistMap) =>

                Artist.fromJson(artistMap as Map<String, dynamic>))

            .toList();

      }



      if (loadFullLibrary) {

        try {

          _cachedAllAlbums = await _db.getAllAlbums();

          _cachedAllSongs = await _db.getAllSongs();

        } catch (_) {}

      }



      final lastUpdate = prefs.getInt(_lastUpdateKey);

      if (lastUpdate != null) {

        _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdate);

      }

    } catch (_) {}

  }



  void _scheduleBackgroundRefresh() {

    if (_subsonicService.isYoutube || _serverOfflineMode || _localOnlyMode)

      return;



    final isLibraryEmpty = _cachedAllAlbums.isEmpty || _cachedAllSongs.isEmpty;

    final shouldRefresh = isLibraryEmpty ||

        _lastCacheUpdate == null ||

        DateTime.now().difference(_lastCacheUpdate!) > const Duration(hours: 6);



    if (shouldRefresh) {

      Future.delayed(const Duration(seconds: 2), () {

        if (!_isBackgroundSyncing) {

          _syncFuture = _refreshAllDataInBackground();

        }

      });

    }

  }



  Future<void> _refreshAllDataInBackground() async {

    if (_subsonicService.isYoutube || _serverOfflineMode || _localOnlyMode)

      return;

    if (_isBackgroundSyncing) {

      if (_syncFuture != null) await _syncFuture;

      return;

    }



    _isBackgroundSyncing = true;

    try {

      const pageSize = 500;

      int offset = 0;

      final List<Album> allAlbums = [];

      final seenSongIds = <String>{};



      while (true) {

        final page = await _subsonicService.getAlbumList(

          type: 'alphabeticalByName',

          size: pageSize,

          offset: offset,

        );

        if (page.isEmpty) break;

        allAlbums.addAll(page);

        await _db.insertAlbumsBatch(page);

        if (page.length < pageSize) break;

        offset += pageSize;

      }



      // Immediately publish albums so Albums view is instantly populated

      if (allAlbums.isNotEmpty) {

        _cachedAllAlbums = List.from(allAlbums);

        notifyListeners();

      }



      if (_subsonicService.isJellyfin) {

        try {

          final allSongs = await _subsonicService.getAllSongs();

          for (final song in allSongs) {

            seenSongIds.add(song.id);

          }

          await _db.insertSongsBatch(allSongs);

          _cachedAllSongs = allSongs;

          notifyListeners();

        } catch (_) {}

      }



      if (seenSongIds.isEmpty) {

        final albumCount = await _db.getAlbumCount();

        const albumBatchSize = 50;

        const concurrency = 6;

        for (int batchOffset = 0;

            batchOffset < albumCount;

            batchOffset += albumBatchSize) {

          final albums = await _db.getAlbumsPaginated(

            limit: albumBatchSize,

            offset: batchOffset,

          );

          for (int i = 0; i < albums.length; i += concurrency) {

            final end = (i + concurrency < albums.length)

                ? i + concurrency

                : albums.length;

            final chunk = albums.sublist(i, end);

            final results = await Future.wait(

              chunk.map((album) async {

                try {

                  return await _subsonicService.getAlbumSongs(album.id);

                } catch (_) {

                  return <Song>[];

                }

              }),

            );

            final batchSongs = <Song>[];

            for (final albumSongs in results) {

              for (final song in albumSongs) {

                if (seenSongIds.add(song.id)) {

                  batchSongs.add(song);

                }

              }

            }

            if (batchSongs.isNotEmpty) {

              await _db.insertSongsBatch(batchSongs);

            }

          }

          // Intermediate batch processed - avoid spamming notifyListeners to prevent infinite UI refetches

        }

      }



      _cachedAllAlbums =

          allAlbums.isNotEmpty ? allAlbums : await _db.getAllAlbums();

      _cachedAllSongs = await _db.getAllSongs();

      _lastCacheUpdate = DateTime.now();



      await _saveCachedData();

      notifyListeners();

    } catch (e) {

      debugPrint('[LibraryProvider] _refreshAllDataInBackground error: $e');

    } finally {

      _isBackgroundSyncing = false;

      _syncFuture = null;

    }

  }



  Future<void> _saveCachedData() async {

    try {

      if (!_subsonicService.isYoutube) {

        await _db.insertAlbumsBatch(_cachedAllAlbums);

        await _db.insertSongsBatch(_cachedAllSongs);

      }



      final prefs = await SharedPreferences.getInstance();

      final playlistsJson = json.encode(

        _cachedPlaylists.map((playlist) => playlist.toJson()).toList(),

      );

      await prefs.setString(_playlistsCacheKey, playlistsJson);



      if (!_subsonicService.isYoutube && _artists.isNotEmpty) {

        final artistsJson = json.encode(

          _artists.map((artist) => artist.toJson()).toList(),

        );

        await prefs.setString(_artistsCacheKey, artistsJson);

      }



      await prefs.setInt(

        _lastUpdateKey,

        _lastCacheUpdate?.millisecondsSinceEpoch ??

            DateTime.now().millisecondsSinceEpoch,

      );

    } catch (_) {}

  }



  void _preloadCoverArt() {

    Future.microtask(() async {

      final allAlbums = [..._recentAlbums, ..._randomAlbums];

      for (final album in allAlbums.take(20)) {

        if (album.coverArt != null) {

          try {

            final url = _subsonicService.getCoverArtUrl(

              album.coverArt,

              size: 300,

            );

            if (url.isNotEmpty) {

              _subsonicService.getCoverArtUrl(album.coverArt, size: 300);

            }

          } catch (_) {}

        }

      }

    });

  }



  Future<void> refresh() async {

    _isInitialized = false;

    _lastCacheUpdate = null;

    _artists = [];

    _cachedAllAlbums = [];

    _cachedAllSongs = [];

    _recentAlbums = [];

    _frequentAlbums = [];

    _newestAlbums = [];

    _randomAlbums = [];

    _playlists = [];

    _cachedPlaylists = [];

    _randomSongs = [];

    _richGenres = [];

    _genres = [];

    _starred = null;

    ImageUrlCache.clear();

    try {

      if (!_subsonicService.isYoutube) {

        await _db.clearServerData();

      }

    } catch (_) {}

    notifyListeners();

    await initialize();



    if (!_serverOfflineMode && !_localOnlyMode && !_subsonicService.isYoutube) {

      _syncFuture = _refreshAllDataInBackground();

      await _syncFuture;

    }

  }



  Future<void> loadArtists() async {

    if (_serverOfflineMode) return;

    try {

      _artists = await _subsonicService.getArtists();

      notifyListeners();

      _audioHandler

          .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdArtists]);

      _saveCachedData();

    } catch (_) {}

  }



  Future<void> loadRecentAlbums() async {

    if (_serverOfflineMode) return;

    try {

      final fetched = await _subsonicService.getAlbumList(

        type: 'recent',

        size: 20,

      );

      if (fetched.isNotEmpty) {

        _recentAlbums = fetched;

      }

      notifyListeners();

      _audioHandler

          .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdAlbums]);

    } catch (_) {}

  }



  Future<void> loadFrequentAlbums() async {

    if (_serverOfflineMode) return;

    try {

      _frequentAlbums = await _subsonicService.getAlbumList(

        type: 'frequent',

        size: 20,

      );

      notifyListeners();

    } catch (_) {}

  }



  Future<void> loadNewestAlbums() async {

    if (_serverOfflineMode) return;

    try {

      _newestAlbums = await _subsonicService.getAlbumList(

        type: 'newest',

        size: 20,

      );

      notifyListeners();

    } catch (_) {}

  }



  Future<void> loadRandomAlbums() async {

    if (_serverOfflineMode) return;

    try {

      _randomAlbums = await _subsonicService.getAlbumList(

        type: 'random',

        size: 20,

      );

      notifyListeners();

    } catch (_) {}

  }



  Future<void> loadPlaylists() async {

    if (_serverOfflineMode) return;

    try {

      final newPlaylists = await _subsonicService.getPlaylists();

      final List<Playlist> mergedPlaylists = [];



      for (final newPlaylist in newPlaylists) {
        final localDbPl = await _db.getPlaylist(newPlaylist.id);
        final cachedIndex = _cachedPlaylists.indexWhere(
          (playlist) => playlist.id == newPlaylist.id,
        );
        final cached = cachedIndex != -1 ? _cachedPlaylists[cachedIndex] : null;

        final effectiveCoverArt =
            (newPlaylist.coverArt != null && newPlaylist.coverArt!.isNotEmpty)
                ? newPlaylist.coverArt
                : (localDbPl?.coverArt ?? cached?.coverArt);

        final localSongs = (localDbPl?.songs != null && localDbPl!.songs!.isNotEmpty)
            ? localDbPl.songs
            : cached?.songs;

        if (localSongs != null && localSongs.isNotEmpty) {
          mergedPlaylists.add(newPlaylist.copyWith(
            songs: localSongs,
            songCount: localSongs.length,
            coverArt: effectiveCoverArt,
          ));
          continue;
        }

        if (effectiveCoverArt != newPlaylist.coverArt) {
          mergedPlaylists
              .add(newPlaylist.copyWith(coverArt: effectiveCoverArt));
          continue;
        }

        mergedPlaylists.add(newPlaylist);
      }

      _playlists = mergedPlaylists;
      _cachedPlaylists = _playlists;
      for (final pl in mergedPlaylists) {
        if (pl.songs != null && pl.songs!.isNotEmpty) {
          try {
            await _db.insertOrUpdatePlaylist(pl);
          } catch (_) {}
        }
      }
      _saveCachedData();

      notifyListeners();

      _audioHandler

          .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdPlaylists]);

    } catch (_) {

      if (_playlists.isEmpty && _cachedPlaylists.isNotEmpty) {

        _playlists = _cachedPlaylists;

        notifyListeners();

      }

    }

  }



  Future<void> loadRandomSongs() async {

    if (_serverOfflineMode) return;

    try {

      final songs = await _subsonicService.getFlatSongs(limit: 50, sort: 'recent');

      _randomSongs = songs;

      if (songs.isNotEmpty) {

        final existingMap = {for (final song in _cachedAllSongs) song.id: song};

        for (final song in songs) {

          existingMap[song.id] = song;

        }

        _cachedAllSongs = existingMap.values.toList();



        final artistMap = <String, int>{};

        for (final song in _cachedAllSongs) {

          if (song.artist != null &&

              song.artist!.isNotEmpty &&

              song.artist != 'Unknown') {

            artistMap[song.artist!] = (artistMap[song.artist!] ?? 0) + 1;

          }

        }

        _artists = artistMap.keys

            .map((name) => Artist(id: 'yt-$name', name: name))

            .toList();

      }

      notifyListeners();

      _audioHandler

          .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdRecent]);

    } catch (_) {}

  }



  Future<void> loadGenres() async {

    if (_serverOfflineMode) return;

    try {

      _richGenres = await _subsonicService.getGenres();

      _genres = _richGenres.map((genre) => genre.value).toList();

      notifyListeners();

    } catch (_) {}

  }



  Future<void> loadStarred() async {

    if (_serverOfflineMode) return;

    try {

      _starred = await _subsonicService.getStarred();

      notifyListeners();

    } catch (_) {}

  }



  Future<List<Album>> getArtistAlbums(String artistId) async {

    if (_localOnlyMode && _localMusicService != null) {

      return _localMusicService!.getAlbumsByArtist(artistId);

    }

    try {

      return await _subsonicService.getArtistAlbums(artistId);

    } catch (_) {

      return [];

    }

  }



  Future<List<Song>> getAlbumSongs(String albumId) async {

    if (_localOnlyMode && _localMusicService != null) {

      return _localMusicService!.getSongsByAlbum(albumId);

    }

    try {

      return await _subsonicService.getAlbumSongs(albumId);

    } catch (_) {

      return [];

    }

  }



  @override

  Future<Playlist> getPlaylist(String playlistId) async {

    if (playlistId == DiscoveryService.kDiscoveryPlaylistId) {

      final discovery = DiscoveryService().currentDiscoveryPlaylist;

      if (discovery != null) return discovery;

    }

    if (_serverOfflineMode) {

      final cached = _playlists.firstWhere(

        (playlist) => playlist.id == playlistId,

        orElse: () => _cachedPlaylists.firstWhere(

          (playlist) => playlist.id == playlistId,

          orElse: () => throw Exception('Playlist not available offline'),

        ),

      );

      return cached;

    }



    try {

      var playlist = await _subsonicService.getPlaylist(playlistId);

      // Fusionner les titres sauvegardés localement (titres virtuels Deezer / locaux)
      final localPl = await _db.getPlaylist(playlistId);
      if (localPl != null && localPl.songs != null && localPl.songs!.isNotEmpty) {
        final serverSongs = List<Song>.from(playlist.songs ?? []);
        final serverSongIds = serverSongs.map((s) => s.id).toSet();
        for (final localSong in localPl.songs!) {
          if (!serverSongIds.contains(localSong.id)) {
            serverSongs.add(localSong);
          }
        }
        playlist = playlist.copyWith(
          songs: serverSongs,
          songCount: serverSongs.length,
        );
      }

      final index = _playlists.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        if ((playlist.coverArt == null || playlist.coverArt!.isEmpty) &&
            _playlists[index].coverArt != null &&
            _playlists[index].coverArt!.isNotEmpty) {
          playlist = playlist.copyWith(coverArt: _playlists[index].coverArt);
        }
        _playlists[index] = playlist;
      } else {
        _playlists.add(playlist);
      }

      _cachedPlaylists = List.from(_playlists);
      _saveCachedData();
      notifyListeners();
      return playlist;
    } catch (e) {
      final localPl = await _db.getPlaylist(playlistId);
      if (localPl != null && localPl.songs != null && localPl.songs!.isNotEmpty) {
        return localPl;
      }
      final cachedPlaylist = _playlists.firstWhere(
        (playlist) => playlist.id == playlistId,
        orElse: () => throw e,
      );

      if (cachedPlaylist.songs != null && cachedPlaylist.songs!.isNotEmpty) {
        return cachedPlaylist;
      }

      rethrow;
    }

  }



  Future<void> createPlaylist(String name, {List<String>? songIds}) async {

    await _subsonicService.createPlaylist(name: name, songIds: songIds);

    await loadPlaylists();

  }



  Future<Playlist> importPlaylistFromPreview({

    required PlaylistImportPreview preview,

    String? customName,

    void Function(int current, int total, String status)? onProgress,

  }) async {

    final playlist = await PlaylistImportService().importFromPreview(

      preview,

      customName: customName,

      onProgress: onProgress,

    );

    await loadPlaylists();

    return playlist;

  }



  Future<Playlist> importPlaylistFromUrl({

    required String urlOrId,

    String? customName,

    void Function(int current, int total, String status)? onProgress,

  }) async {

    final playlist = await PlaylistImportService().importFromUrl(

      urlOrId,

      customName: customName,

      onProgress: onProgress,

    );

    await loadPlaylists();

    return playlist;

  }



  Future<void> deletePlaylist(String playlistId) async {

    _playlists.removeWhere((p) => p.id == playlistId);

    _cachedPlaylists.removeWhere((p) => p.id == playlistId);

    _saveCachedData();

    notifyListeners();

    _audioHandler

        .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdPlaylists]);

    try {

      await _db.deletePlaylist(playlistId);

      await _subsonicService.deletePlaylist(playlistId);

    } finally {

      await loadPlaylists();

    }

  }



  Future<void> updatePlaylistInMemoryAndDb(Playlist updated) async {
    final idx = _playlists.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _playlists[idx] = updated;
    } else {
      _playlists.add(updated);
    }
    final cIdx = _cachedPlaylists.indexWhere((p) => p.id == updated.id);
    if (cIdx != -1) {
      _cachedPlaylists[cIdx] = updated;
    } else {
      _cachedPlaylists.add(updated);
    }
    try {
      await _db.insertOrUpdatePlaylist(updated);
    } catch (_) {}
    _saveCachedData();
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    // 1. Toujours charger la playlist complète (fusion serveur + local + mémoire)
    Playlist fullPlaylist;
    try {
      fullPlaylist = await getPlaylist(playlistId);
    } catch (_) {
      final local = await _db.getPlaylist(playlistId);
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      final inMem = idx != -1 ? _playlists[idx] : Playlist(id: playlistId, name: 'Playlist');
      if (local != null && local.songs != null && local.songs!.isNotEmpty) {
        fullPlaylist = local;
      } else {
        fullPlaylist = inMem;
      }
    }

    // 2. Ajouter la chanson si elle n'est pas déjà présente
    final currentSongs = List<Song>.from(fullPlaylist.songs ?? []);
    final alreadyPresent = currentSongs.any((s) => s.id == song.id);
    if (!alreadyPresent) {
      currentSongs.add(song);
    }

    final updated = fullPlaylist.copyWith(
      songs: currentSongs,
      songCount: currentSongs.length,
      changed: DateTime.now(),
    );

    // 3. Mettre à jour la mémoire et SQLite immédiatement
    await updatePlaylistInMemoryAndDb(updated);

    // 4. Mise à jour de la cover mosaïque 2x2
    PlaylistCoverService().checkAndGenerateCover(
      playlistId: playlistId,
      songs: currentSongs,
      subsonicService: _subsonicService,
    );

    // 5. Synchronisation serveur Navidrome/Subsonic (uniquement pour les morceaux locaux au serveur)
    final isVirtual = song.id.startsWith('cj_dz_') ||
        song.id.startsWith('dz_') ||
        song.id.startsWith('yt_') ||
        (song.path == null && !song.isLocal && song.id.length < 20);

    if (!song.isLocal && !isVirtual) {
      try {
        await _subsonicService.updatePlaylist(
          playlistId: playlistId,
          songIdsToAdd: [song.id],
        );
      } catch (e) {
        debugPrint('[LibraryProvider] Server updatePlaylist (ignoring for local/virtual tracks): ');
      }
    }
  }



  static String _normalizeSearch(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _scoreRelevance(String text, String query) {
    final normText = _normalizeSearch(text);
    final normQuery = _normalizeSearch(query);
    if (normText.isEmpty || normQuery.isEmpty) return 0;

    if (normText == normQuery) return 10000;
    if (normText.startsWith(normQuery)) return 5000;

    final words = normText.split(' ');
    for (final w in words) {
      if (w.startsWith(normQuery)) return 3000;
    }

    if (normText.contains(normQuery)) return 1000;
    return 100;
  }

  @override
  Future<SearchResult> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return SearchResult(artists: [], albums: [], songs: []);
    }

    if (_localOnlyMode) {
      return _searchLocal(cleanQuery);
    }

    final subsonicFuture = _subsonicService
        .search(cleanQuery)
        .catchError((_) => SearchResult(artists: [], albums: [], songs: []));

    final autoFuture = DeezerService()
        .searchAutocomplete(cleanQuery)
        .catchError((_) => (songs: <Song>[], artists: <Artist>[], albums: <Album>[]));

    final deezerSongsFuture =
        DeezerService().searchTracks(cleanQuery, limit: 30).catchError((_) => <Song>[]);

    final deezerArtistsFuture =
        DeezerService().searchArtists(cleanQuery, limit: 15).catchError((_) => <Artist>[]);

    final deezerAlbumsFuture =
        DeezerService().searchAlbums(cleanQuery, limit: 15).catchError((_) => <Album>[]);

    final results = await Future.wait([
      subsonicFuture,
      autoFuture,
      deezerSongsFuture,
      deezerArtistsFuture,
      deezerAlbumsFuture,
    ]);

    final subResult = results[0] as SearchResult;
    final autoResult = results[1] as ({List<Song> songs, List<Artist> artists, List<Album> albums});
    final deezerSongs = results[2] as List<Song>;
    final deezerArtists = results[3] as List<Artist>;
    final deezerAlbums = results[4] as List<Album>;

    // Fusionner les titres : Autocomplétion prioritaire + serveur + catalogue universel
    final Set<String> seenIds = {};
    final List<Song> mergedSongs = [];

    void addSongIfNew(Song s) {
      final key = '${_normalizeSearch(s.title)}_${_normalizeSearch(s.artist ?? "")}';
      if (seenIds.add(s.id) && seenIds.add(key)) {
        mergedSongs.add(s);
      }
    }

    for (final s in autoResult.songs) {
      addSongIfNew(s);
    }
    for (final s in subResult.songs) {
      addSongIfNew(s);
    }
    for (final s in deezerSongs) {
      addSongIfNew(s);
    }

    // Fusionner les artistes
    final Set<String> seenArtistNames = {};
    final List<Artist> mergedArtists = [];

    void addArtistIfNew(Artist a) {
      final key = _normalizeSearch(a.name);
      if (key.isNotEmpty && seenArtistNames.add(key)) {
        mergedArtists.add(a);
      }
    }

    for (final a in autoResult.artists) {
      addArtistIfNew(a);
    }
    for (final a in subResult.artists) {
      addArtistIfNew(a);
    }
    for (final a in deezerArtists) {
      addArtistIfNew(a);
    }

    // Fusionner les albums
    final Set<String> seenAlbumNames = {};
    final List<Album> mergedAlbums = [];

    void addAlbumIfNew(Album alb) {
      final key = '${_normalizeSearch(alb.name)}_${_normalizeSearch(alb.artist ?? "")}';
      if (seenAlbumNames.add(key)) {
        mergedAlbums.add(alb);
      }
    }

    for (final alb in autoResult.albums) {
      addAlbumIfNew(alb);
    }
    for (final alb in subResult.albums) {
      addAlbumIfNew(alb);
    }
    for (final alb in deezerAlbums) {
      addAlbumIfNew(alb);
    }

    // Tri de pertinence intelligent (Préfixe exact > Début de mot > Contient)
    mergedArtists.sort((a, b) {
      final scoreA = _scoreRelevance(a.name, cleanQuery);
      final scoreB = _scoreRelevance(b.name, cleanQuery);
      return scoreB.compareTo(scoreA);
    });

    mergedSongs.sort((a, b) {
      final scoreTitleA = _scoreRelevance(a.title, cleanQuery);
      final scoreArtistA = _scoreRelevance(a.artist ?? '', cleanQuery);
      final maxA = scoreTitleA > scoreArtistA ? scoreTitleA : scoreArtistA;

      final scoreTitleB = _scoreRelevance(b.title, cleanQuery);
      final scoreArtistB = _scoreRelevance(b.artist ?? '', cleanQuery);
      final maxB = scoreTitleB > scoreArtistB ? scoreTitleB : scoreArtistB;

      return maxB.compareTo(maxA);
    });

    mergedAlbums.sort((a, b) {
      final scoreA = _scoreRelevance(a.name, cleanQuery);
      final scoreB = _scoreRelevance(b.name, cleanQuery);
      return scoreB.compareTo(scoreA);
    });

    return SearchResult(
      artists: mergedArtists,
      albums: mergedAlbums,
      songs: mergedSongs,
    );
  }



  Future<void> cacheSongLocally(Song song) async {

    await cacheSongsLocally([song]);

  }



  Future<void> cacheSongsLocally(List<Song> songs) async {

    final newSongs =

        songs.where((s) => !_cachedAllSongs.any((c) => c.id == s.id)).toList();

    if (newSongs.isNotEmpty) {

      _cachedAllSongs.addAll(newSongs);

      if (!_subsonicService.isYoutube) {

        await _db.insertSongsBatch(newSongs);

      }

      notifyListeners();

    }

  }



  SearchResult _searchLocal(String query) {

    final lowerQuery = query.toLowerCase();

    final songs = _cachedAllSongs

        .where(

          (song) =>

              song.title.toLowerCase().contains(lowerQuery) ||

              (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||

              (song.album?.toLowerCase().contains(lowerQuery) ?? false),

        )

        .take(50)

        .toList();

    final artists = _artists

        .where((artist) => artist.name.toLowerCase().contains(lowerQuery))

        .take(20)

        .toList();

    final albums = _cachedAllAlbums

        .where(

          (album) =>

              album.name.toLowerCase().contains(lowerQuery) ||

              (album.artist?.toLowerCase().contains(lowerQuery) ?? false),

        )

        .take(20)

        .toList();

    return SearchResult(songs: songs, artists: artists, albums: albums);

  }



  Future<void> star({String? songId, String? albumId, String? artistId}) async {

    await _subsonicService.star(

      id: songId,

      albumId: albumId,

      artistId: artistId,

    );

    await loadStarred();

  }



  Future<void> unstar({

    String? songId,

    String? albumId,

    String? artistId,

  }) async {

    await _subsonicService.unstar(

      id: songId,

      albumId: albumId,

      artistId: artistId,

    );

    await loadStarred();

  }



  @override

  Future<List<Song>> getSongsByGenre(String genre) async {

    try {

      return await _subsonicService.getSongsByGenre(genre);

    } catch (_) {

      return [];

    }

  }



  Future<List<Album>> getAlbumsByGenre(String genre) async {

    try {

      return await _subsonicService.getAlbumsByGenre(genre);

    } catch (_) {

      return [];

    }

  }



  Future<List<Song>> getAllSongs() async {

    try {

      final allArtists = await _subsonicService.getArtists();

      final List<Song> allSongs = [];



      for (final artist in allArtists) {

        try {

          final artistAlbums =

              await _subsonicService.getArtistAlbums(artist.id);

          for (final album in artistAlbums) {

            try {

              final songs = await _subsonicService.getAlbumSongs(album.id);

              allSongs.addAll(songs);

            } catch (_) {}

          }

        } catch (_) {}

      }



      return allSongs;

    } catch (_) {

      return [];

    }

  }



  Future<List<Album>> getAllAlbums() async {

    try {

      final allArtists = await _subsonicService.getArtists();

      final List<Album> allAlbums = [];



      for (final artist in allArtists) {

        try {

          final artistAlbums =

              await _subsonicService.getArtistAlbums(artist.id);

          allAlbums.addAll(artistAlbums);

        } catch (_) {}

      }



      return allAlbums;

    } catch (_) {

      return [];

    }

  }



  @override

  void dispose() {

    _localMusicService?.removeListener(_onLocalMusicServiceChanged);

    super.dispose();

  }

}

