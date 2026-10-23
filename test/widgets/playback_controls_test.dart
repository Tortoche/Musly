import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/providers/player_provider.dart' show RepeatMode;
import 'package:musly/widgets/now_playing/playback_controls.dart';

void main() {
  group('PlaybackControls - Repeat Button Phases (Issue #253)', () {
    testWidgets('Phase 1 (off): displays repeat icon in inactive state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackControls(
              isPlaying: false,
              isShuffleEnabled: false,
              repeatMode: RepeatMode.off,
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
              onShuffleToggle: () {},
              onRepeatToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one_rounded), findsNothing);

      // Verify that the active dot indicator is not shown
      final iconFinder = find.byIcon(Icons.repeat_rounded);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, Colors.white.withValues(alpha: 0.45));
    });

    testWidgets(
        'Phase 2 (all/queue): displays repeat_rounded icon in active state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackControls(
              isPlaying: true,
              isShuffleEnabled: false,
              repeatMode: RepeatMode.all,
              accentColor: const Color(0xFFFA243C),
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
              onShuffleToggle: () {},
              onRepeatToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one_rounded), findsNothing);

      final iconFinder = find.byIcon(Icons.repeat_rounded);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, const Color(0xFFFA243C));
    });

    testWidgets(
        'Phase 3 (single/one): displays repeat_one_rounded icon distinctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackControls(
              isPlaying: true,
              isShuffleEnabled: false,
              repeatMode: RepeatMode.one,
              accentColor: const Color(0xFFFA243C),
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
              onShuffleToggle: () {},
              onRepeatToggle: () {},
            ),
          ),
        ),
      );

      // Distinct repeat_one_rounded icon is shown
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);

      final iconFinder = find.byIcon(Icons.repeat_one_rounded);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, const Color(0xFFFA243C));
    });

    testWidgets('taps on repeat trigger onRepeatToggle callback',
        (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackControls(
              isPlaying: true,
              isShuffleEnabled: false,
              repeatMode: RepeatMode.off,
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
              onShuffleToggle: () {},
              onRepeatToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('backwards-compatibility with isRepeatEnabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackControls(
              isPlaying: true,
              isShuffleEnabled: false,
              isRepeatEnabled: true,
              accentColor: const Color(0xFFFA243C),
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
              onShuffleToggle: () {},
              onRepeatToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.repeat_rounded));
      expect(iconWidget.color, const Color(0xFFFA243C));
    });
  });
}
