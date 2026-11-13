// Pieces shared by the home, playlist and play screens: the overlay button
// and its sheet, the shuffle-mode picker, and the mini player bar.
import 'package:flutter/material.dart';

import 'artwork.dart';
import 'library.dart';
import 'main.dart';
import 'play_screen.dart';

/// Opens the overlay sheet for a playlist. Filled when an overlay is on.
class OverlayButton extends StatelessWidget {
  const OverlayButton(this.playlist, {super.key});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final def = overlayById(playlist.overlayId);
    void open() => showOverlaySheet(context, playlist.name);
    const icon = Icon(Icons.waves);
    final tip = def == null ? 'Overlay: off' : 'Overlay: ${def.label}';
    return def == null
        ? IconButton.outlined(onPressed: open, icon: icon, tooltip: tip)
        : IconButton.filled(onPressed: open, icon: icon, tooltip: tip);
  }
}

/// Choose the overlay (and its volume) for one playlist. Every change is
/// saved at once, which is how the playlist remembers it for next time.
void showOverlaySheet(BuildContext context, String playlistName) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final p = library.byName(playlistName);
        if (p == null) return const SizedBox.shrink();
        Widget option(String? id, String label) => ListTile(
              leading: Icon(p.overlayId == id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(label),
              onTap: () => library.setOverlay(p, id),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Overlay for ${p.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              option(null, 'Off'),
              for (final o in overlays) option(o.id, o.label),
              if (p.overlayId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
                  child: Row(children: [
                    const Icon(Icons.volume_down),
                    Expanded(
                      child: Slider(
                        value: p.overlayVolume,
                        onChanged: (v) => library.setOverlayVolume(p, v),
                      ),
                    ),
                    const Icon(Icons.volume_up),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Text(
                  'Plays underneath this playlist while a track is playing. '
                  'Remembered for this playlist.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// The two-way shuffle setting of a playlist.
class ShuffleModePicker extends StatelessWidget {
  const ShuffleModePicker(this.playlist, {super.key});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ShuffleMode>(
          showSelectedIcon: false,
          segments: [
            for (final m in ShuffleMode.values)
              ButtonSegment(value: m, label: Text(m.shortLabel)),
          ],
          selected: {playlist.shuffleMode},
          onSelectionChanged: (s) => library.setShuffleMode(playlist, s.first),
        ),
        const SizedBox(height: 6),
        Text(
          'Shuffle: ${playlist.shuffleMode.label.toLowerCase()}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Bottom bar showing the loaded track; tap to open the play screen.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final track = player.track;
        if (track == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const PlayScreen()),
              ),
              leading: TrackArt(track,
                  size: 44, fallback: const Icon(Icons.music_note)),
              title: Text(titleOf(track),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(player.playlistName ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                iconSize: 32,
                icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                tooltip: player.playing ? 'Pause' : 'Play',
                onPressed: player.playing ? player.pause : player.play,
              ),
            ),
          ),
        );
      },
    );
  }
}
