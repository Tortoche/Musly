import '../models/lyric_line.dart';

class LrcParser {
  static List<LyricLine> parseLrc(String content) {
    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];

    final RegExp tagRegex = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final matches = tagRegex.allMatches(trimmed).toList();
      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        final text = trimmed.substring(lastMatch.end).trim();

        if (text.isNotEmpty) {
          for (final match in matches) {
            final minutes = int.parse(match.group(1)!);
            final seconds = int.parse(match.group(2)!);
            final fracStr = match.group(3);
            int ms = 0;
            if (fracStr != null) {
              if (fracStr.length == 1) {
                ms = int.parse(fracStr) * 100;
              } else if (fracStr.length == 2) {
                ms = int.parse(fracStr) * 10;
              } else if (fracStr.length >= 3) {
                ms = int.parse(fracStr.substring(0, 3));
              }
            }

            final duration = Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: ms,
            );

            parsedLines.add(LyricLine(
              text: text,
              startTime: duration,
            ));
          }
        }
      }
    }

    if (parsedLines.isEmpty && content.trim().isNotEmpty) {
      final plainLines =
          content.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (var text in plainLines) {
        parsedLines.add(LyricLine(
          text: text,
          startTime: Duration.zero,
        ));
      }
      return parsedLines;
    }

    parsedLines.sort((a, b) => a.startTime.compareTo(b.startTime));

    for (var i = 0; i < parsedLines.length - 1; i++) {
      final current = parsedLines[i];
      final next = parsedLines[i + 1];

      parsedLines[i] = LyricLine(
        text: current.text,
        startTime: current.startTime,
        endTime: next.startTime - const Duration(milliseconds: 1),
        words: current.words,
      );
    }

    return parsedLines;
  }

  static bool hasTimestamps(List<LyricLine> lines) {
    return lines.length > 1 && lines.any((l) => l.startTime > Duration.zero);
  }
}
