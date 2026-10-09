/// Sentence-picker rules (Markus, 2026-10-09): only sentences that follow
/// each other can be chosen together, up to [maxChars] characters in total.
/// A single sentence longer than that may still be chosen on its own,
/// otherwise it could never be explained.
class SentenceSelection {
  static const maxChars = 300;

  /// Character length of each sentence, in order.
  final List<int> lengths;

  /// Selected range as inclusive indexes, or null when nothing is selected.
  final int? first;
  final int? last;

  const SentenceSelection(this.lengths, {this.first, this.last});

  bool get isEmpty => first == null;

  bool isSelected(int i) => !isEmpty && i >= first! && i <= last!;

  int get selectedChars {
    if (isEmpty) return 0;
    var sum = 0;
    for (var i = first!; i <= last!; i++) {
      sum += lengths[i];
    }
    // Sentences are joined with a space.
    return sum + (last! - first!);
  }

  /// Whether tapping sentence [i] does anything: it can be selected, or it
  /// is an end of the range and can be deselected.
  bool canTap(int i) => toggle(i) != null;

  /// The selection after tapping sentence [i], or null when the tap is not
  /// allowed (not adjacent, over the limit, or in the middle of the range).
  SentenceSelection? toggle(int i) {
    if (isEmpty) return SentenceSelection(lengths, first: i, last: i);
    if (first == last && i == first) return SentenceSelection(lengths);
    if (i == first) return SentenceSelection(lengths, first: first! + 1, last: last);
    if (i == last) return SentenceSelection(lengths, first: first, last: last! - 1);
    if (isSelected(i)) return null; // middle: would split the range
    final adjacent = i == first! - 1 || i == last! + 1;
    if (!adjacent) return null;
    final grown = SentenceSelection(
      lengths,
      first: i < first! ? i : first,
      last: i > last! ? i : last,
    );
    return grown.selectedChars <= maxChars ? grown : null;
  }
}
