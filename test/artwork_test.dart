import 'dart:io';

import 'package:audio_player/artwork.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('embedded cover is extracted once; a file without one gives null', () async {
    final tmp = Directory.systemTemp.createTempSync('audio_player_art');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final art = Artwork(Directory('${tmp.path}/art'));

    final cover = await art.of(File('test/fixtures/with_cover.mp3'));
    expect(cover, isNotNull);
    // PNG signature: the picture bytes came through intact.
    expect(cover!.readAsBytesSync().sublist(1, 4), 'PNG'.codeUnits);

    expect(await art.of(File('test/fixtures/no_cover.mp3')), isNull);

    // A second instance (an app relaunch) finds both answers in the cache.
    final again = Artwork(Directory('${tmp.path}/art'));
    expect((await again.of(File('test/fixtures/with_cover.mp3')))!.path, cover.path);
    expect(await again.of(File('test/fixtures/no_cover.mp3')), isNull);
  });
}
