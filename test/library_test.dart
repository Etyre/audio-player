import 'dart:io';

import 'package:audio_player/library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = Directory.systemTemp.createTempSync('audio_player_test');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Library open() => Library(Directory('${tmp.path}/Playlists'), prefs)..init();

  test('first launch seeds the three playlists with their shuffle modes', () {
    final lib = open();
    expect(lib.playlists.map((p) => p.name),
        ['20 minute yoga nidra', '40 minute yoga nidra', 'HIIT music']);
    expect(lib.byName('40 minute yoga nidra')!.shuffleMode, ShuffleMode.one);
    expect(lib.byName('HIIT music')!.shuffleMode, ShuffleMode.continuous);
    // Naps start with pink noise on; the workout playlist with none.
    expect(lib.byName('20 minute yoga nidra')!.overlayId, 'pink');
    expect(lib.byName('40 minute yoga nidra')!.overlayId, 'pink');
    expect(lib.byName('HIIT music')!.overlayId, isNull);
  });

  test('overlay, volume and shuffle mode are remembered per playlist', () {
    var lib = open();
    lib.setOverlay(lib.byName('40 minute yoga nidra')!, null);
    lib.setOverlay(lib.byName('HIIT music')!, 'pink');
    lib.setOverlayVolume(lib.byName('HIIT music')!, 0.2);
    lib.setShuffleMode(lib.byName('20 minute yoga nidra')!, ShuffleMode.continuous);

    lib = open(); // "relaunch"
    expect(lib.byName('40 minute yoga nidra')!.overlayId, isNull,
        reason: 'turning it off sticks; the default is not re-applied');
    expect(lib.byName('HIIT music')!.overlayId, 'pink');
    expect(lib.byName('HIIT music')!.overlayVolume, 0.2);
    expect(lib.byName('20 minute yoga nidra')!.shuffleMode, ShuffleMode.continuous);
  });

  test('tracks are the audio files in the folder, sorted; a deleted seed stays deleted',
      () async {
    var lib = open();
    final dir = lib.byName('HIIT music')!.dir;
    File('${dir.path}/b.mp3').writeAsStringSync('x');
    File('${dir.path}/A.MP3').writeAsStringSync('x');
    File('${dir.path}/notes.txt').writeAsStringSync('x');
    File('${dir.path}/.hidden.mp3').writeAsStringSync('x');
    lib.rescan();
    expect(lib.byName('HIIT music')!.tracks.map(titleOf), ['A', 'b']);

    final src = File('${tmp.path}/c.mp3')..writeAsStringSync('x');
    expect(await lib.addFiles(lib.byName('HIIT music')!, [src.path, src.path]), 1);
    expect(lib.byName('HIIT music')!.tracks.length, 3);

    lib.delete(lib.byName('20 minute yoga nidra')!);
    expect(lib.create('HIIT music'), isNotNull);
    expect(lib.create('Sleep'), isNull);
    lib = open();
    expect(lib.playlists.map((p) => p.name),
        ['40 minute yoga nidra', 'HIIT music', 'Sleep']);
  });
}
