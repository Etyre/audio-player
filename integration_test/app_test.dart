// End-to-end check on a simulator or phone, with real audio players:
//
//   flutter test integration_test -d <device id>
//
// Starts the real app, makes a throwaway playlist of two 2-second tones, and
// checks both shuffle modes and that the overlay starts and stops with the
// track. It deletes the playlist afterwards and touches no other playlist.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_player/library.dart';
import 'package:audio_player/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// A mono 16-bit WAV of a quiet sine tone.
Uint8List tone(double hz, {double seconds = 2}) {
  const rate = 22050;
  final n = (rate * seconds).round();
  final b = ByteData(44 + n * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (3000 * sin(2 * pi * hz * i / rate)).round(),
        Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shuffle modes and overlay, end to end', (tester) async {
    await app.main();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Playlists'), findsOneWidget);

    const name = 'zz integration test';
    final old = app.library.byName(name);
    if (old != null) app.library.delete(old);
    expect(app.library.create(name), isNull);
    var p = app.library.byName(name)!;
    File('${p.dir.path}/tone a.wav').writeAsBytesSync(tone(330));
    File('${p.dir.path}/tone b.wav').writeAsBytesSync(tone(440));
    app.library.rescan();
    p = app.library.byName(name)!;
    expect(p.tracks.length, 2);

    Future<void> wait(bool Function() until, String what) async {
      for (var i = 0; i < 100 && !until(); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(until(), isTrue, reason: 'timed out waiting for: $what');
    }

    try {
      // Through the screens: home -> playlist -> tap a specific track ->
      // overlay sheet -> play screen.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(find.text(name), 200);
      await tester.tap(find.text(name));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Shuffle play'), findsOneWidget);
      await tester.tap(find.text('tone b'));
      await wait(() => app.player.playing, 'tapped track playing');
      expect(app.player.index, 1);
      await app.player.pause();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.waves));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Pink noise'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.library.byName(name)!.overlayId, 'pink');
      await tester.tapAt(const Offset(20, 60)); // dismiss the sheet
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('tone b').last); // the mini player
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Stops when this song ends'), findsOneWidget);
      expect(find.text('Pink noise'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump(const Duration(seconds: 1));
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Playlists'), findsOneWidget);
      p = app.library.byName(name)!;

      // Mode 1: play a random song, then stop. Overlay on.
      app.library.setShuffleMode(p, ShuffleMode.one);
      app.library.setOverlay(p, 'pink');
      await app.player.playShuffled(p);
      await wait(() => app.player.playing, 'track playing');
      await wait(() => app.player.overlayPlaying, 'overlay playing');
      final first = app.player.index;
      await wait(() => !app.player.playing, 'stop after one song');
      await wait(() => !app.player.overlayPlaying, 'overlay stops with it');
      expect(app.player.index, first, reason: 'did not move to another song');
      expect(app.player.position, Duration.zero);

      // The overlay choice was saved for this playlist.
      app.library.rescan();
      p = app.library.byName(name)!;
      expect(p.overlayId, 'pink');

      // Mode 2: continue at random. Overlay off.
      app.library.setShuffleMode(p, ShuffleMode.continuous);
      app.library.setOverlay(p, null);
      await app.player.playTrack(p, 0);
      await wait(() => app.player.playing, 'specific track playing');
      expect(app.player.index, 0);
      expect(app.player.overlayPlaying, isFalse);
      await wait(() => app.player.index == 1, 'moved on to the other song');
      await wait(() => app.player.index == 0, 'and on again');
      expect(app.player.playing, isTrue);

      // Turning the overlay on mid-track starts it; pausing stops both.
      app.library.setOverlay(p, 'pink');
      await wait(() => app.player.overlayPlaying, 'overlay on mid-track');
      await app.player.pause();
      await wait(() => !app.player.overlayPlaying, 'overlay pauses with track');

      // The link a Shortcut would open does the same as the shuffle button.
      app.handleLink(
          Uri.parse('audioplayer://shuffle?playlist=ZZ%20Integration%20TEST'));
      await wait(() => app.player.playing, 'link starts shuffle play');
      await wait(() => app.player.overlayPlaying, 'with its overlay');
    } finally {
      await app.player.clear();
      app.library.delete(app.library.byName(name)!);
    }
  });
}
