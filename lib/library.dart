// The playlists on disk and their settings.
//
// A playlist is a folder: <app Documents>/Playlists/<playlist name>/ holding
// audio files. Nothing else records which tracks belong to it, so tracks can
// be added from inside the app, from the Files app (On My iPhone > Audio
// Player), or pushed from the Mac with tool/push_music.sh, and all three look
// the same to the app. Per-playlist settings (shuffle mode, overlay) live in
// SharedPreferences under "playlist.<name>".
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the shuffle button does for a playlist.
enum ShuffleMode {
  one('Play a random song, then stop', 'One, then stop'),
  continuous('Continue playing songs at random', 'Keep going');

  const ShuffleMode(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

/// A sound that loops underneath the playlist. Add a line to [overlays] and a
/// file under assets/overlays/ to offer another one.
class OverlayDef {
  const OverlayDef(this.id, this.label, this.asset);
  final String id;
  final String label;
  final String asset;
}

const overlays = [
  OverlayDef('pink', 'Pink noise', 'assets/overlays/pink_noise.wav'),
];

OverlayDef? overlayById(String? id) {
  for (final o in overlays) {
    if (o.id == id) return o;
  }
  return null;
}

/// Track title shown in the UI: the file name without its extension.
String titleOf(File f) {
  final name = f.path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

class Playlist {
  Playlist(this.name, this.dir);

  final String name;
  final Directory dir;
  List<File> tracks = [];
  ShuffleMode shuffleMode = ShuffleMode.one;

  /// The overlay last chosen for this playlist; null means off.
  String? overlayId;
  double overlayVolume = 0.5;
}

class Library extends ChangeNotifier {
  Library(this.root, this.prefs);

  /// The "Playlists" folder.
  final Directory root;
  final SharedPreferences prefs;
  List<Playlist> playlists = [];

  // Formats both iOS and Android decode natively.
  static const audioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'flac'];

  static const _seed = {
    '20 minute yoga nidra': ShuffleMode.one,
    '40 minute yoga nidra': ShuffleMode.one,
    'HIIT music': ShuffleMode.continuous,
  };

  /// Creates the starter playlists on the very first launch only, so one the
  /// user deletes later stays deleted. "seedVersion" records which of these
  /// one-time steps have run.
  void init() {
    root.createSync(recursive: true);
    final done = prefs.getInt('seedVersion') ??
        (prefs.getBool('seeded') == true ? 1 : 0);
    if (done < 1) {
      for (final e in _seed.entries) {
        Directory('${root.path}/${e.key}').createSync();
        if (prefs.getString('playlist.${e.key}') == null) {
          _save(Playlist(e.key, Directory('${root.path}/${e.key}'))
            ..shuffleMode = e.value);
        }
      }
      prefs.setStringList('playlistOrder', _seed.keys.toList());
    }
    if (done < 2) {
      // The yoga nidras are for naps with pink noise: start with it on, so
      // the shuffle button alone is enough.
      for (final name in _seed.keys.where((n) => n.contains('yoga nidra'))) {
        final dir = Directory('${root.path}/$name');
        if (!dir.existsSync()) continue;
        final p = _load(name, dir);
        if (p.overlayId == null) _save(p..overlayId = overlays.first.id);
      }
    }
    prefs.setInt('seedVersion', 2);
    rescan();
  }

  /// Re-reads the folders. Called on launch, on returning to the app (files
  /// may have been added through the Files app) and after every change.
  void rescan() {
    final dirs = {
      for (final d in root.listSync().whereType<Directory>())
        if (!_name(d.path).startsWith('.')) _name(d.path): d,
    };
    final order = prefs.getStringList('playlistOrder') ?? [];
    final names = [
      ...order.where(dirs.containsKey),
      ...(dirs.keys.where((n) => !order.contains(n)).toList()..sort(_byName)),
    ];
    prefs.setStringList('playlistOrder', names);
    playlists = [for (final n in names) _load(n, dirs[n]!)];
    notifyListeners();
  }

  Playlist? byName(String? name) {
    for (final p in playlists) {
      if (p.name == name) return p;
    }
    return null;
  }

  void setShuffleMode(Playlist p, ShuffleMode mode) {
    p.shuffleMode = mode;
    _save(p);
    notifyListeners();
  }

  void setOverlay(Playlist p, String? overlayId) {
    p.overlayId = overlayId;
    _save(p);
    notifyListeners();
  }

  void setOverlayVolume(Playlist p, double volume) {
    p.overlayVolume = volume;
    _save(p);
    notifyListeners();
  }

  /// Returns an error message, or null when the playlist was created.
  String? create(String rawName) {
    final name = rawName.replaceAll(RegExp(r'[/\\:]'), ' ').trim();
    if (name.isEmpty || name.startsWith('.')) return 'Give the playlist a name.';
    final dir = Directory('${root.path}/$name');
    if (dir.existsSync()) return 'There is already a playlist called "$name".';
    dir.createSync();
    rescan();
    return null;
  }

  void delete(Playlist p) {
    if (p.dir.existsSync()) p.dir.deleteSync(recursive: true);
    prefs.remove('playlist.${p.name}');
    rescan();
  }

  /// Copies audio files into the playlist. A file whose name is already there
  /// is left alone. Returns how many were added.
  Future<int> addFiles(Playlist p, Iterable<String> paths) async {
    var added = 0;
    for (final path in paths) {
      final target = File('${p.dir.path}/${_name(path)}');
      if (!_isAudio(path) || target.existsSync()) continue;
      await File(path).copy(target.path);
      added++;
    }
    rescan();
    return added;
  }

  void removeTrack(File f) {
    if (f.existsSync()) f.deleteSync();
    rescan();
  }

  Playlist _load(String name, Directory dir) {
    final p = Playlist(name, dir)
      ..tracks = (dir
          .listSync()
          .whereType<File>()
          .where((f) => !_name(f.path).startsWith('.') && _isAudio(f.path))
          .toList()
        ..sort((a, b) => _byName(_name(a.path), _name(b.path))));
    final raw = prefs.getString('playlist.$name');
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        p.shuffleMode = ShuffleMode.values.asNameMap()[j['shuffleMode']] ??
            ShuffleMode.one;
        p.overlayId = overlayById(j['overlay'] as String?)?.id;
        p.overlayVolume = (j['overlayVolume'] as num?)?.toDouble() ?? 0.5;
      } catch (e) {
        debugPrint('Bad settings for playlist "$name", using defaults: $e');
      }
    }
    return p;
  }

  void _save(Playlist p) => prefs.setString(
        'playlist.${p.name}',
        jsonEncode({
          'shuffleMode': p.shuffleMode.name,
          'overlay': p.overlayId,
          'overlayVolume': p.overlayVolume,
        }),
      );

  static String _name(String path) => path.split(Platform.pathSeparator).last;
  static int _byName(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
  static bool _isAudio(String path) =>
      audioExtensions.contains(path.split('.').last.toLowerCase());
}
