// The play screen: what is playing, the seek bar, transport buttons, and the
// overlay button for the playing playlist.
import 'package:flutter/material.dart';

import 'library.dart';
import 'main.dart';
import 'widgets.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  double? _dragSeconds; // non-null while the user holds the seek bar

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, player]),
      builder: (context, _) {
        final track = player.track;
        final p = player.playlist;
        final theme = Theme.of(context);
        if (track == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Nothing is playing.')),
          );
        }
        final what = (p?.shuffleMode ?? ShuffleMode.one) == ShuffleMode.one
            ? 'Stops when this song ends'
            : 'Then keeps playing at random';
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(player.playlistName ?? ''),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Icon(Icons.graphic_eq,
                      size: 96, color: theme.colorScheme.primary),
                  const Spacer(),
                  Text(titleOf(track),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(what, style: theme.textTheme.bodyMedium),
                  if (player.error != null) ...[
                    const SizedBox(height: 8),
                    Text(player.error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snap) {
                      final total = player.duration ?? Duration.zero;
                      final max = total.inMilliseconds / 1000;
                      final pos = (_dragSeconds ??
                              (snap.data ?? player.position).inMilliseconds /
                                  1000)
                          .clamp(0.0, max);
                      return Column(children: [
                        Slider(
                          max: max <= 0 ? 1 : max,
                          value: max <= 0 ? 0 : pos,
                          onChanged: max <= 0
                              ? null
                              : (v) => setState(() => _dragSeconds = v),
                          onChangeEnd: (v) {
                            player.seek(
                                Duration(milliseconds: (v * 1000).round()));
                            setState(() => _dragSeconds = null);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_clock(
                                  Duration(milliseconds: (pos * 1000).round()))),
                              Text(_clock(total)),
                            ],
                          ),
                        ),
                      ]);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 44,
                        icon: const Icon(Icons.skip_previous),
                        tooltip: 'Previous',
                        onPressed: player.skipToPrevious,
                      ),
                      IconButton.filled(
                        iconSize: 56,
                        padding: const EdgeInsets.all(12),
                        icon: Icon(
                            player.playing ? Icons.pause : Icons.play_arrow),
                        tooltip: player.playing ? 'Pause' : 'Play',
                        onPressed: player.playing ? player.pause : player.play,
                      ),
                      IconButton(
                        iconSize: 44,
                        icon: const Icon(Icons.skip_next),
                        tooltip: 'Another random song',
                        onPressed: player.skipToNext,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (p != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OverlayButton(p),
                        const SizedBox(width: 12),
                        Text(overlayById(p.overlayId)?.label ?? 'Overlay off'),
                      ],
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
