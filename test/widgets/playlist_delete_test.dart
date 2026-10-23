import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/models/playlist.dart';
import 'package:musly/models/song.dart';
import 'package:musly/widgets/modals/playlist_options_modal.dart';
import 'package:musly/screens/detail/playlist_screen.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/services/audio_handler.dart';
import 'package:musly/providers/library_provider.dart';
import '../test_helpers.dart';
import '../bootstrap.dart';

class FakePlaylistSubsonicService extends SubsonicService {
  String? deletedPlaylistId;
  final bool _isYoutube;

  FakePlaylistSubsonicService({bool isYoutube = false})
      : _isYoutube = isYoutube;

  @override
  bool get isYoutube => _isYoutube;

  @override
  Future<Playlist> getPlaylist(String id) async {
    return Playlist(
      id: id,
      name: 'My Cool Playlist',
      songs: [
        Song(id: 's1', title: 'Song 1', artist: 'Artist 1'),
      ],
    );
  }

  @override
  Future<void> deletePlaylist(String id) async {
    deletedPlaylistId = id;
  }
}

class TestPlaylistLibraryProvider extends LibraryProvider {
  final List<Playlist> _testPlaylists;
  String? lastDeletedId;

  TestPlaylistLibraryProvider({
    required SubsonicService subsonicService,
    required MuslyAudioHandler audioHandler,
    required List<Playlist> testPlaylists,
  })  : _testPlaylists = List.from(testPlaylists),
        super(subsonicService, audioHandler);

  @override
  List<Playlist> get playlists => _testPlaylists;

  @override
  Future<void> deletePlaylist(String playlistId) async {
    lastDeletedId = playlistId;
    _testPlaylists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    try {
      await subsonicService.deletePlaylist(playlistId);
    } catch (_) {}
  }
}

void main() {
  initializeTestEnvironment();

  group('Playlist Deletion Tests', () {
    testWidgets('PlaylistOptionsModal displays playlist info and delete option',
        (
      WidgetTester tester,
    ) async {
      final testPlaylist = Playlist(
        id: 'pl-1',
        name: 'My Cool Playlist',
        songCount: 5,
      );

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    PlaylistOptionsModal.show(context, testPlaylist),
                child: const Text('Open Options'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      expect(find.text('My Cool Playlist'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
    });

    testWidgets('PlaylistScreen contains delete playlist menu item', (
      WidgetTester tester,
    ) async {
      final fakeSubsonic = FakePlaylistSubsonicService();
      final testPlaylist = Playlist(
        id: 'pl-1',
        name: 'My Cool Playlist',
        songs: [
          Song(id: 's1', title: 'Song 1', artist: 'Artist 1'),
        ],
      );
      final testLibraryProvider = TestPlaylistLibraryProvider(
        subsonicService: fakeSubsonic,
        audioHandler: MuslyAudioHandler(),
        testPlaylists: [testPlaylist],
      );

      await tester.pumpWidget(
        createTestApp(
          subsonicService: fakeSubsonic,
          libraryProvider: testLibraryProvider,
          child: const PlaylistScreen(
            playlistId: 'pl-1',
            playlistName: 'My Cool Playlist',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final popupMenu = find.byType(PopupMenuButton<String>);
      expect(popupMenu, findsOneWidget);

      await tester.tap(popupMenu);
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
    });

    testWidgets(
        'Deleting playlist removes it from LibraryProvider and calls subsonicService on Web Stream',
        (
      WidgetTester tester,
    ) async {
      final fakeSubsonic = FakePlaylistSubsonicService();
      final testPlaylist = Playlist(
        id: 'yt-playlist-123',
        name: 'My Web Stream Playlist',
        songCount: 2,
      );

      final testLibraryProvider = TestPlaylistLibraryProvider(
        subsonicService: fakeSubsonic,
        audioHandler: MuslyAudioHandler(),
        testPlaylists: [testPlaylist],
      );

      await tester.pumpWidget(
        createTestApp(
          subsonicService: fakeSubsonic,
          libraryProvider: testLibraryProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await PlaylistOptionsModal.confirmAndDelete(
                    context, testPlaylist);
              },
              child: const Text('Delete'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Tap confirm button in AlertDialog
      final deleteConfirmButton = find.widgetWithText(TextButton, 'Elimina');
      final fallbackDeleteButton = find.widgetWithText(TextButton, 'Delete');
      if (deleteConfirmButton.evaluate().isNotEmpty) {
        await tester.tap(deleteConfirmButton);
      } else {
        await tester.tap(fallbackDeleteButton);
      }
      await tester.pumpAndSettle();

      // Verify the playlist is removed from provider and subsonicService was called
      expect(
          testLibraryProvider.playlists.any((p) => p.id == 'yt-playlist-123'),
          isFalse);
      expect(testLibraryProvider.lastDeletedId, equals('yt-playlist-123'));
      expect(fakeSubsonic.deletedPlaylistId, equals('yt-playlist-123'));
    });

    testWidgets(
        'Tapping delete inside PlaylistOptionsModal bottom sheet deletes the playlist on Web Stream',
        (
      WidgetTester tester,
    ) async {
      final fakeSubsonic = FakePlaylistSubsonicService(isYoutube: true);
      final testPlaylist = Playlist(
        id: 'yt-playlist-456',
        name: 'My Web Stream Playlist 2',
        songCount: 3,
      );

      final testLibraryProvider = TestPlaylistLibraryProvider(
        subsonicService: fakeSubsonic,
        audioHandler: MuslyAudioHandler(),
        testPlaylists: [testPlaylist],
      );

      await tester.pumpWidget(
        createTestApp(
          subsonicService: fakeSubsonic,
          libraryProvider: testLibraryProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                PlaylistOptionsModal.show(context, testPlaylist);
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Find trash icon inside the modal bottom sheet
      expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.trash));
      await tester.pumpAndSettle();

      // Tap confirm button in AlertDialog
      final deleteConfirmButton = find.widgetWithText(TextButton, 'Elimina');
      final fallbackDeleteButton = find.widgetWithText(TextButton, 'Delete');
      if (deleteConfirmButton.evaluate().isNotEmpty) {
        await tester.tap(deleteConfirmButton);
      } else {
        await tester.tap(fallbackDeleteButton);
      }
      await tester.pumpAndSettle();

      // Verify the playlist is removed from provider and subsonicService was called
      expect(
          testLibraryProvider.playlists.any((p) => p.id == 'yt-playlist-456'),
          isFalse);
      expect(testLibraryProvider.lastDeletedId, equals('yt-playlist-456'));
      expect(fakeSubsonic.deletedPlaylistId, equals('yt-playlist-456'));
    });

    testWidgets(
        'Deleting playlist from PlaylistScreen 3-dots menu removes it and calls subsonicService',
        (
      WidgetTester tester,
    ) async {
      final fakeSubsonic = FakePlaylistSubsonicService(isYoutube: true);
      final testPlaylist = Playlist(
        id: 'pl-detail-1',
        name: 'Detail Screen Playlist',
        songs: [
          Song(id: 's1', title: 'Song 1', artist: 'Artist 1'),
        ],
      );
      final testLibraryProvider = TestPlaylistLibraryProvider(
        subsonicService: fakeSubsonic,
        audioHandler: MuslyAudioHandler(),
        testPlaylists: [testPlaylist],
      );

      await tester.pumpWidget(
        createTestApp(
          subsonicService: fakeSubsonic,
          libraryProvider: testLibraryProvider,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (ctx) => const PlaylistScreen(
                playlistId: 'pl-detail-1',
                playlistName: 'Detail Screen Playlist',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final popupMenu = find.byType(PopupMenuButton<String>);
      expect(popupMenu, findsOneWidget);

      await tester.tap(popupMenu);
      await tester.pumpAndSettle();

      final deleteMenuItem = find.text('Elimina Playlist');
      final fallbackMenuItem = find.text('Delete Playlist');
      if (deleteMenuItem.evaluate().isNotEmpty) {
        await tester.tap(deleteMenuItem);
      } else if (fallbackMenuItem.evaluate().isNotEmpty) {
        await tester.tap(fallbackMenuItem);
      }
      await tester.pumpAndSettle();

      final deleteConfirmButton = find.widgetWithText(TextButton, 'Elimina');
      final fallbackDeleteButton = find.widgetWithText(TextButton, 'Delete');
      if (deleteConfirmButton.evaluate().isNotEmpty) {
        await tester.tap(deleteConfirmButton);
      } else {
        await tester.tap(fallbackDeleteButton);
      }
      await tester.pumpAndSettle();

      expect(testLibraryProvider.playlists.any((p) => p.id == 'pl-detail-1'),
          isFalse);
      expect(testLibraryProvider.lastDeletedId, equals('pl-detail-1'));
      expect(fakeSubsonic.deletedPlaylistId, equals('pl-detail-1'));
    });
  });
}
