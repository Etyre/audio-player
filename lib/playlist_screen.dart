// One playlist: its tracks (tap one to play that track), shuffle
// play, the shuffle setting, the overlay, and adding or removing tracks.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart' show shufflePlay;
import 'library.dart';
import 'main.dart';
import 'widgets.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen(this.playlistName, {super.key});
  final String playlistName;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _adding = false;

  Future<void> _addTracks(Playlist p) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: Library.audioExtensions,
      );
      final paths = [for (final f in picked) if (f.path != null) f.path!];
      if (paths.isEmpty) return;
      final added = await library.addFiles(p, paths);
      // The picker hands us temporary copies; ours are in the playlist now.
      for (final path in paths) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      final skipped = paths.length - added;
      messenger.showSnackBar(SnackBar(
          content: Text('Added $added track${added == 1 ? '' : 's'}'
              '${skipped > 0 ? ' ($skipped already there or not audio)' : ''}')));
    } catch (e) {
      debugPrint('Adding tracks failed: $e');
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not add those files.')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: Text(p.tracks.isEmpty
            ? 'The playlist is empty.'
            : 'Its ${p.tracks.length} audio file(s) are deleted from this app too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (player.playlistName == p.name) await player.clear();
    if (!mounted) return;
    Navigator.of(context).pop();
    library.delete(p);
  }

  Future<void> _removeTrack(File f) async {
    await player.forget(f);
    library.removeTrack(f);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, player]),
      builder: (context, _) {
        final p = library.byName(widget.playlistName);
        if (p == null) return const Scaffold(body: SizedBox.shrink());
        final theme = Theme.of(context);
        final current =
            player.playlistName == p.name ? player.track?.path : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add tracks',
                onPressed: _adding ? null : () => _addTracks(p),
              ),
              PopupMenuButton<String>(
                onSelected: (_) => _delete(p),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: const MiniPlayer(),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Shuffle play'),
                          onPressed: () => shufflePlay(context, p),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OverlayButton(p),
                    ]),
                    const SizedBox(height: 12),
                    ShuffleModePicker(p),
                  ],
                ),
              ),
              const Divider(),
              if (_adding) const LinearProgressIndicator(),
              if (p.tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    const Text(
                      'No tracks yet.\n\nAdd audio files here, or drop them into '
                      'this playlist\'s folder in the Files app under '
                      'On My iPhone › Audio Player › Playlists.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add tracks'),
                      onPressed: _adding ? null : () => _addTracks(p),
                    ),
                  ]),
                ),
              for (final (i, f) in p.tracks.indexed)
                ListTile(
                  leading: Icon(
                    f.path == current
                        ? (player.playing ? Icons.volume_up : Icons.pause)
                        : Icons.music_note,
                    color: f.path == current ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    titleOf(f),
                    style: f.path == current
                        ? TextStyle(color: theme.colorScheme.primary)
                        : null,
                  ),
                  onTap: () => player.playTrack(p, i),
                  trailing: PopupMenuButton<String>(
                    onSelected: (_) => _removeTrack(f),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'remove', child: Text('Remove from playlist')),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
