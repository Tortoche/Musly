import 'package:flutter_test/flutter_test.dart';
import 'package:musly/services/playlist_import_service.dart';

void main() {
  group('PlaylistImportService - Provider Detection', () {
    final service = PlaylistImportService();

    test('detects Spotify web URLs correctly', () {
      expect(
        service.detectSource(
            'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=12345'),
        PlaylistImportSource.spotify,
      );
      expect(
        service.detectSource(
            'https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        PlaylistImportSource.spotify,
      );
      expect(
        service.detectSource('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
        PlaylistImportSource.spotify,
      );
      expect(
        service.detectSource('37i9dQZF1DXcBWIGoYBM5M'),
        PlaylistImportSource.spotify,
      );
    });

    test('detects YouTube Music and YouTube URLs correctly', () {
      expect(
        service.detectSource(
            'https://music.youtube.com/playlist?list=PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        PlaylistImportSource.youtubeMusic,
      );
      expect(
        service.detectSource(
            'https://www.youtube.com/playlist?list=PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        PlaylistImportSource.youtubeMusic,
      );
      expect(
        service.detectSource('https://youtu.be/playlist?list=PLFgquLnL59al'),
        PlaylistImportSource.youtubeMusic,
      );
      expect(
        service.detectSource('PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        PlaylistImportSource.youtubeMusic,
      );
      expect(
        service.detectSource('VLPLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        PlaylistImportSource.youtubeMusic,
      );
    });

    test('returns unknown for unsupported links', () {
      expect(
        service.detectSource('https://example.com/not-a-playlist'),
        PlaylistImportSource.unknown,
      );
    });
  });

  group('PlaylistImportService - ID Extraction', () {
    final service = PlaylistImportService();

    test('extracts Spotify ID from various link formats', () {
      expect(
        service.extractSpotifyId(
            'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=xyz'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(
        service.extractSpotifyId(
            'https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(
        service.extractSpotifyId('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
      expect(
        service.extractSpotifyId('37i9dQZF1DXcBWIGoYBM5M'),
        '37i9dQZF1DXcBWIGoYBM5M',
      );
    });

    test('extracts YouTube playlist ID correctly', () {
      expect(
        service.extractYouTubePlaylistId(
            'https://music.youtube.com/playlist?list=PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth&si=abc'),
        'PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth',
      );
      expect(
        service.extractYouTubePlaylistId(
            'https://www.youtube.com/playlist?list=PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        'PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth',
      );
      expect(
        service.extractYouTubePlaylistId('PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        'PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth',
      );
      expect(
        service
            .extractYouTubePlaylistId('VLPLFgquLnL59alW3xmYiWRaoz0oM3H17Lth'),
        'PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth',
      );
    });
  });

  group('PlaylistImportService - Live preview fetching (No login)', () {
    final service = PlaylistImportService();

    test('fetches public Spotify playlist preview without login', () async {
      final preview = await service.fetchSpotifyPreview(
          'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M');

      expect(preview.source, PlaylistImportSource.spotify);
      expect(preview.title, isNotEmpty);
      expect(preview.tracks, isNotEmpty);
      expect(preview.tracks.first.title, isNotEmpty);
      expect(preview.tracks.first.artist, isNotEmpty);
    });

    test('fetches public YouTube Music playlist preview without login',
        () async {
      final preview = await service.fetchYouTubeMusicPreview(
          'https://music.youtube.com/playlist?list=PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth');

      expect(preview.source, PlaylistImportSource.youtubeMusic);
      expect(preview.title, isNotEmpty);
      expect(preview.tracks, isNotEmpty);
      expect(preview.tracks.first.youtubeVideoId, isNotNull);
      expect(preview.tracks.first.youtubeVideoId!.length, 11);
    });

    test('matches Spotify track to YouTube Music track', () async {
      final videoId = await service.matchSpotifyTrackToYouTube(
        'Blinding Lights',
        'The Weeknd',
        duration: 200,
      );

      expect(videoId, isNotNull);
      expect(videoId!.length, 11);
    });

    test('matches Spotify track with high-res 1:1 square cover art', () async {
      final details = await service.matchSpotifyTrackToYouTubeDetails(
        'Blinding Lights',
        'The Weeknd',
        duration: 200,
      );

      expect(details, isNotNull);
      expect(details!.videoId.length, 11);
      expect(details.coverArt, isNotNull);
      expect(details.coverArt, isNot(contains('hqdefault.jpg')));
      // Should be upscaled Google CDN image (800x800)
      if (details.coverArt!.contains('googleusercontent.com') ||
          details.coverArt!.contains('ggpht.com')) {
        expect(details.coverArt, contains('w800-h800'));
      }
    });

    test('YouTube Music preview provides high-res 1:1 cover art', () async {
      final preview = await service.fetchYouTubeMusicPreview(
          'https://music.youtube.com/playlist?list=PLFgquLnL59alW3xmYiWRaoz0oM3H17Lth');

      expect(preview.tracks, isNotEmpty);
      final firstTrack = preview.tracks.first;
      expect(firstTrack.coverArt, isNotNull);
      expect(firstTrack.coverArt, isNot(contains('hqdefault.jpg')));
      if (firstTrack.coverArt!.contains('googleusercontent.com') ||
          firstTrack.coverArt!.contains('ggpht.com')) {
        expect(firstTrack.coverArt, contains('w800-h800'));
      }
    });
  });
}
