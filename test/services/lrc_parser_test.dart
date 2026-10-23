import 'package:flutter_test/flutter_test.dart';
import 'package:musly/services/lrc_ttml_parser.dart';

void main() {
  group('LrcParser', () {
    test('parses standard [mm:ss.xx] formatted LRC', () {
      const content = '''
[00:12.50]First line
[00:15.80]Second line
[01:02.10]Third line
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('First line'));
      expect(lines[0].startTime,
          equals(const Duration(seconds: 12, milliseconds: 500)));
      expect(lines[1].text, equals('Second line'));
      expect(lines[1].startTime,
          equals(const Duration(seconds: 15, milliseconds: 800)));
      expect(lines[2].text, equals('Third line'));
      expect(lines[2].startTime,
          equals(const Duration(minutes: 1, seconds: 2, milliseconds: 100)));
      expect(LrcParser.hasTimestamps(lines), isTrue);
    });

    test('parses colon-separated timestamps [mm:ss:xx]', () {
      const content = '''
[00:10:50]Line one
[00:20:00]Line two
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Line one'));
      expect(lines[0].startTime,
          equals(const Duration(seconds: 10, milliseconds: 500)));
      expect(lines[1].text, equals('Line two'));
      expect(lines[1].startTime, equals(const Duration(seconds: 20)));
      expect(LrcParser.hasTimestamps(lines), isTrue);
    });

    test('parses single-digit minute timestamps [m:ss.xx]', () {
      const content = '''
[1:05.25]Single digit minute
[2:30.00]Two minutes thirty
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(2));
      expect(lines[0].startTime,
          equals(const Duration(minutes: 1, seconds: 5, milliseconds: 250)));
      expect(
          lines[1].startTime, equals(const Duration(minutes: 2, seconds: 30)));
      expect(LrcParser.hasTimestamps(lines), isTrue);
    });

    test('parses timestamps without fractions [mm:ss]', () {
      const content = '''
[00:05]Intro
[00:15]Verse
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(2));
      expect(lines[0].startTime, equals(const Duration(seconds: 5)));
      expect(lines[1].startTime, equals(const Duration(seconds: 15)));
      expect(LrcParser.hasTimestamps(lines), isTrue);
    });

    test('parses lines with multiple timestamp tags', () {
      const content = '''
[00:10.00][00:30.00]Chorus line
[00:20.00]Verse line
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(3));
      // Sorted chronologically
      expect(lines[0].startTime, equals(const Duration(seconds: 10)));
      expect(lines[0].text, equals('Chorus line'));
      expect(lines[1].startTime, equals(const Duration(seconds: 20)));
      expect(lines[1].text, equals('Verse line'));
      expect(lines[2].startTime, equals(const Duration(seconds: 30)));
      expect(lines[2].text, equals('Chorus line'));
      expect(LrcParser.hasTimestamps(lines), isTrue);
    });

    test('handles plain text without timestamps as unsynced', () {
      const content = '''
First line of plain lyrics
Second line of plain lyrics
Third line of plain lyrics
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('First line of plain lyrics'));
      expect(lines[0].startTime, equals(Duration.zero));
      expect(lines[1].startTime, equals(Duration.zero));
      expect(lines[2].startTime, equals(Duration.zero));
      // hasTimestamps is false because all timestamps are Duration.zero
      expect(LrcParser.hasTimestamps(lines), isFalse);
    });

    test('ignores metadata tags like [ti:], [ar:], [al:]', () {
      const content = '''
[ti:Title]
[ar:Artist]
[al:Album]
[00:10.00]First real line
[00:20.00]Second real line
''';
      final lines = LrcParser.parseLrc(content);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('First real line'));
      expect(lines[1].text, equals('Second real line'));
      expect(LrcParser.hasTimestamps(lines), isTrue);
    });
  });
}
