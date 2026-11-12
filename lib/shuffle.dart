import 'dart:math';

/// Hands out the indices 0..size-1 in random order: every index once before
/// any repeats, and never the same index twice in a row across a refill.
/// Used for "continue playing songs at random" so a 7-track playlist does not
/// play the same track three times in an evening.
class ShuffleBag {
  /// [last] is the index that has just been played, if any; it will not be
  /// the first one handed out.
  ShuffleBag(this.size, {Random? random, int? last})
      : _random = random ?? Random(),
        // ignore: prefer_initializing_formals
        _last = last;

  final int size;
  final Random _random;
  final List<int> _bag = []; // consumed from the end
  int? _last;

  int next() {
    if (_bag.isEmpty) {
      _bag
        ..addAll(List.generate(size, (i) => i))
        ..shuffle(_random);
      if (size > 1 && _bag.last == _last) {
        _bag[_bag.length - 1] = _bag[0];
        _bag[0] = _last!;
      }
    }
    return _last = _bag.removeLast();
  }
}
