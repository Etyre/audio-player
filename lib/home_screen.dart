// Home: the list of playlists. Each row opens the playlist, and carries its
// own overlay button and shuffle-play button.
import 'package:flutter/material.dart';

import 'library.dart';
import 'main.dart';
import 'playlist_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New playlist',
            onPressed: () => showDialog<void>(
                context: context, builder: (_) => const NewPlaylistDialog()),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: Listenable.merge([library, player]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            for (final p in library.playlists) _PlaylistCard(p),
            if (library.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No playlists. Tap + to make one.',
                    textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard(this.playlist);
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    final theme = Theme.of(context);
    final isCurrent = player.playlistName == p.name && player.track != null;
    final count = p.tracks.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlaylistScreen(p.name)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: isCurrent ? theme.colorScheme.primary : null),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${count == 0 ? 'Empty' : count == 1 ? '1 track' : '$count tracks'}'
                      ' · ${p.shuffleMode.shortLabel.toLowerCase()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              OverlayButton(p),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                iconSize: 28,
                icon: const Icon(Icons.shuffle),
                tooltip: 'Shuffle play',
                onPressed: () => shufflePlay(context, p),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starts shuffle play, or says why not.
void shufflePlay(BuildContext context, Playlist p) {
  if (p.tracks.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('"${p.name}" is empty. Open it to add tracks.')));
    return;
  }
  player.playShuffled(p);
}

/// Name a new playlist. The typed name is saved on every keystroke under
/// "draft.newPlaylistName" and survives closing the dialog or the app; it is
/// cleared only when the playlist is created.
class NewPlaylistDialog extends StatefulWidget {
  const NewPlaylistDialog({super.key});

  @override
  State<NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _NewPlaylistDialogState extends State<NewPlaylistDialog> {
  static const _draftKey = 'draft.newPlaylistName';
  late final _name =
      TextEditingController(text: prefs.getString(_draftKey) ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final error = library.create(_name.text);
    if (error != null) return setState(() => _error = error);
    prefs.remove(_draftKey);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        spellCheckConfiguration: const SpellCheckConfiguration(),
        decoration: InputDecoration(labelText: 'Name', errorText: _error),
        onChanged: (v) => prefs.setString(_draftKey, v),
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }
}
