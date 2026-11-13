// Playback: one player for the playlist's tracks and a second, looping one
// for the overlay. Registered with audio_service so playback continues with
// the screen locked and the lock screen / headphones can control it.
//
// The overlay is independent of the track. It starts when a playlist that
// has an overlay chosen starts playing, and from then on only its own
// play/pause control (or choosing "Off") stops it: it keeps going when the
// track is paused and after "play a random song, then stop" has ended, so
// the pink noise carries on for the rest of a nap. The lock screen and
// headphone buttons have a single play/pause, which acts on both together.
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'artwork.dart';
import 'library.dart';
import 'shuffle.dart';

class PlayerHandler extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  PlayerHandler(this.library, this.artwork) {
    _init();
  }

  final Library library;
  final Artwork artwork;
  final _player = AudioPlayer();
  final _overlay = AudioPlayer();

  /// What is loaded. The list is a snapshot of the playlist's tracks taken
  /// when playback started.
  String? playlistName;
  List<File> files = [];
  int index = -1;

  /// Set when a track could not be loaded; shown on the play screen.
  String? error;

  ShuffleBag? _bag;
  final List<int> _history = []; // tracks played before this one, for "previous"
  String? _loadedOverlayId;
  String? _seenOverlayId; // the loaded playlist's overlay, as last seen
  bool _completing = false;
  Future<void> _overlayQueue = Future.value();
  // What the lock screen's pause button paused, for its play button to resume.
  bool _resumeTrack = false;
  bool _resumeOverlay = false;

  File? get track => index >= 0 && index < files.length ? files[index] : null;
  Playlist? get playlist => library.byName(playlistName);
  bool get playing => _player.playing;
  bool get overlayPlaying => _overlay.playing;

  /// The overlay chosen for the loaded playlist, if any.
  OverlayDef? get overlayDef => overlayById(playlist?.overlayId);
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Stream<Duration> get positionStream => _player.positionStream;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _overlay.setLoopMode(LoopMode.one);
    _player.playerStateStream.listen(_onState);
    _player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e) => debugPrint('Playback error: $e'),
    );
    _player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (item != null && d != null) mediaItem.add(item.copyWith(duration: d));
      notifyListeners();
    });
    _overlay.playingStream.listen((_) {
      _broadcast();
      notifyListeners();
    });
    // An overlay or volume change made in the UI lands in the library first.
    library.addListener(_onLibraryChanged);
  }

  // ---- starting playback -------------------------------------------------

  // However a track was started, what happens when it ends is the playlist's
  // shuffle mode (stop, or go on to a random track), read at that moment so a
  // change made mid-track takes effect.

  /// Plays one specific track of the playlist.
  Future<void> playTrack(Playlist p, int i) async {
    _load(p, justPlayed: i);
    _setOverlay(play: overlayDef != null);
    await _start(i);
  }

  /// Plays a random track of the playlist.
  Future<void> playShuffled(Playlist p) async {
    if (p.tracks.isEmpty) return;
    _load(p);
    _setOverlay(play: overlayDef != null);
    await _start(_bag!.next());
  }

  void _load(Playlist p, {int? justPlayed}) {
    playlistName = p.name;
    files = List.of(p.tracks);
    _bag = ShuffleBag(files.length, last: justPlayed);
    _history.clear();
    _seenOverlayId = p.overlayId;
    _resumeTrack = _resumeOverlay = false;
  }

  Future<void> _start(int i) async {
    index = i;
    error = null;
    final f = files[i];
    mediaItem.add(MediaItem(id: f.path, title: titleOf(f), album: playlistName));
    notifyListeners();
    // Cover for the lock screen, once it has been read from the file.
    unawaited(artwork.of(f).then((art) {
      final item = mediaItem.value;
      if (art != null && item?.id == f.path) {
        mediaItem.add(item!.copyWith(artUri: art.uri));
      }
    }).catchError((Object e) {
      debugPrint('Cover error: $e');
    }));
    try {
      await _player.setFilePath(f.path);
    } on PlayerInterruptedException {
      return; // another track was started while this one was loading
    } catch (e) {
      debugPrint('Could not load ${f.path}: $e');
      error = 'Could not play this file.';
      await _player.pause();
      notifyListeners();
      return;
    }
    unawaited(_player.play());
  }

  // ---- transport ---------------------------------------------------------

  // The track's own controls (the buttons in the app).
  void resumeTrack() {
    if (track != null) unawaited(_player.play());
  }

  Future<void> pauseTrack() => _player.pause();

  /// The overlay's own play/pause control.
  void toggleOverlay() => _setOverlay(play: !_overlay.playing);

  // Lock screen and headphone buttons: one control for everything audible.
  @override
  Future<void> pause() async {
    _resumeTrack = _player.playing;
    _resumeOverlay = _overlay.playing;
    _setOverlay(play: false);
    await _player.pause();
  }

  @override
  Future<void> play() async {
    if (_resumeOverlay) _setOverlay(play: true);
    if (_resumeTrack || !_resumeOverlay) resumeTrack();
    _resumeTrack = _resumeOverlay = false;
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    _setOverlay(play: false);
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  @override
  Future<void> skipToNext() async {
    if (track == null) return;
    _history.add(index);
    await _start(_bag!.next());
  }

  @override
  Future<void> skipToPrevious() async {
    if (track == null) return;
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_history.isNotEmpty) {
      await _start(_history.removeLast());
    } else {
      await _player.seek(Duration.zero);
    }
  }

  // ---- keeping up with library edits -------------------------------------

  /// Unloads everything, e.g. when the playing playlist is deleted.
  Future<void> clear() async {
    playlistName = null;
    files = [];
    index = -1;
    _history.clear();
    _setOverlay(play: false);
    await _player.stop();
    mediaItem.add(null);
    notifyListeners();
  }

  /// Call before deleting a track's file.
  Future<void> forget(File f) async {
    final i = files.indexWhere((q) => q.path == f.path);
    if (i < 0) return;
    if (i == index) return clear();
    files.removeAt(i);
    if (i < index) index--;
    _bag = ShuffleBag(files.length, last: index);
    _history.clear();
  }

  // ---- internals ---------------------------------------------------------

  void _onState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      if (!_completing) {
        _completing = true;
        _onCompleted().whenComplete(() => _completing = false);
      }
      return;
    }
    _broadcast();
    notifyListeners();
  }

  Future<void> _onCompleted() async {
    int? next;
    if (playlist?.shuffleMode == ShuffleMode.continuous) {
      _history.add(index);
      next = _bag!.next();
    }
    if (next != null) {
      await _start(next);
    } else {
      // Rewind so the play button starts the same track again.
      await _player.pause();
      await _player.seek(Duration.zero);
    }
    _broadcast();
    notifyListeners();
  }

  void _onLibraryChanged() {
    final id = playlist?.overlayId;
    final changed = id != _seenOverlayId;
    _seenOverlayId = id;
    // Choosing an overlay while a track plays starts it; choosing "Off"
    // stops it (inside _setOverlay); a volume change just passes through.
    _setOverlay(play: changed && id != null && _player.playing ? true : null);
  }

  /// Loads the loaded playlist's overlay and its volume, then plays or
  /// pauses it if [play] says so (null leaves it as it is). With no overlay
  /// chosen it is always paused. Calls are queued so a quick series of
  /// changes cannot interleave.
  void _setOverlay({bool? play}) {
    _overlayQueue = _overlayQueue.then((_) async {
      final def = overlayDef;
      try {
        if (def == null) {
          if (_overlay.playing) await _overlay.pause();
          return;
        }
        if (_loadedOverlayId != def.id) {
          await _overlay.setAsset(def.asset);
          _loadedOverlayId = def.id;
        }
        await _overlay.setVolume(playlist!.overlayVolume);
        if (play == true && !_overlay.playing) {
          unawaited(_overlay.play());
        } else if (play == false && _overlay.playing) {
          await _overlay.pause();
        }
      } catch (e) {
        debugPrint('Overlay error: $e');
      }
    });
  }

  void _broadcast() {
    // Also "playing" while only the overlay sounds, so the lock screen
    // offers pause for it.
    final playing = _player.playing || _overlay.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: index < 0 ? null : index,
    ));
  }
}
