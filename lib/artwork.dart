// Cover art embedded in the audio files (ID3 "APIC", MP4 "covr", FLAC
// pictures). Each track's picture is pulled out once and kept as a file in
// the app's cache folder, because the lock screen wants a file URL and
// re-reading tags on every rebuild would be wasteful. A zero-length cache
// file means "looked, this track has none".
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'main.dart' show artwork;

class Artwork {
  Artwork(this.cacheDir) {
    cacheDir.createSync(recursive: true);
  }

  final Directory cacheDir;
  final _memo = <String, Future<File?>>{};

  /// The cover image file for [track], or null if it has none.
  Future<File?> of(File track) {
    final FileStat st = track.statSync();
    // Keyed on playlist/file name (not the full path: the app container's
    // path changes between installs) plus size and date, so a replaced file
    // gets its new cover.
    final parts = track.path.split(Platform.pathSeparator);
    final tail = parts.skip(parts.length > 2 ? parts.length - 2 : 0).join('/');
    final key = '${tail.hashCode.toUnsigned(32).toRadixString(16)}'
        '_${st.size}_${st.modified.millisecondsSinceEpoch}';
    return _memo.putIfAbsent(key, () async {
      final out = File('${cacheDir.path}/$key');
      if (!out.existsSync()) {
        final bytes = await compute(_readCover, track.path);
        out.writeAsBytesSync(bytes ?? const []);
      }
      return out.lengthSync() > 0 ? out : null;
    });
  }
}

/// Runs on a background isolate: tag parsing reads a fair amount of file.
Uint8List? _readCover(String path) {
  try {
    final pictures = readMetadata(File(path), getImage: true).pictures;
    if (pictures.isEmpty) return null;
    final front = pictures.where((p) => p.pictureType == PictureType.coverFront);
    return (front.isEmpty ? pictures.first : front.first).bytes;
  } catch (e) {
    debugPrint('No readable tags in $path: $e');
    return null;
  }
}

/// A track's cover as a rounded square; [fallback] when it has none.
class TrackArt extends StatelessWidget {
  const TrackArt(this.track, {required this.size, required this.fallback, super.key});
  final File track;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<File?>(
        future: artwork.of(track),
        builder: (context, snap) {
          final art = snap.data;
          if (art == null) return Center(child: fallback);
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.12),
            child: Image.file(
              art,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => Center(child: fallback),
            ),
          );
        },
      ),
    );
  }
}
