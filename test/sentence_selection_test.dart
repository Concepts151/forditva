import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/tutor/sentence_selection.dart';

void main() {
  // Five sentences of 100 characters each (joined with spaces).
  const five = [100, 100, 100, 100, 100];

  test('first tap selects any sentence', () {
    final s = const SentenceSelection(five).toggle(3)!;
    expect([s.first, s.last], [3, 3]);
  });

  test('only adjacent sentences can be added', () {
    final s = const SentenceSelection(five, first: 1, last: 1);
    expect(s.toggle(2), isNotNull);
    expect(s.toggle(0), isNotNull);
    expect(s.toggle(3), isNull, reason: '1 and 3 are not consecutive');
  });

  test('cannot go over 300 characters', () {
    // 0..1 = 201 chars; adding a third gives 302.
    final s = const SentenceSelection(five, first: 0, last: 1);
    expect(s.selectedChars, 201);
    expect(s.toggle(2), isNull);
  });

  test('only the ends can be deselected', () {
    final s = const SentenceSelection([50, 50, 50], first: 0, last: 2);
    expect(s.toggle(1), isNull, reason: 'would split the range');
    final shrunk = s.toggle(0)!;
    expect([shrunk.first, shrunk.last], [1, 2]);
  });

  test('tapping the only selected sentence clears the selection', () {
    final s = const SentenceSelection(five, first: 2, last: 2).toggle(2)!;
    expect(s.isEmpty, isTrue);
  });

  test('a sentence over 300 characters can be chosen alone, not combined', () {
    final s = const SentenceSelection([400, 20]).toggle(0)!;
    expect(s.selectedChars, 400);
    expect(s.toggle(1), isNull);
  });
}
