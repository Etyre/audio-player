import 'dart:math';

import 'package:audio_player/shuffle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every track plays once per round, never twice in a row', () {
    for (var seed = 0; seed < 200; seed++) {
      final bag = ShuffleBag(5, random: Random(seed));
      final picks = [for (var i = 0; i < 50; i++) bag.next()];
      for (var round = 0; round < 10; round++) {
        expect(picks.sublist(round * 5, round * 5 + 5).toSet(), {0, 1, 2, 3, 4});
      }
      for (var i = 1; i < picks.length; i++) {
        expect(picks[i], isNot(picks[i - 1]), reason: 'seed $seed, pick $i');
      }
    }
  });

  test('a one-track playlist just repeats', () {
    final bag = ShuffleBag(1);
    expect([bag.next(), bag.next(), bag.next()], [0, 0, 0]);
  });

  test('the track just played by hand is not the first random pick', () {
    for (var seed = 0; seed < 200; seed++) {
      expect(ShuffleBag(3, random: Random(seed), last: 2).next(), isNot(2));
    }
  });
}
