# Audio Player

An MP3 player for iPhone and Android (Flutter), built 2026-11-12, organised
around playlists rather than a library. It exists for two uses: lying down
and having one random yoga nidra play and then stop, and shuffling workout
music without end. Each playlist has a shuffle-play button right on the home
screen, its own shuffle setting, and remembers the overlay (pink noise) last
used with it.

## How it works

- **A playlist is a folder.** `<app Documents>/Playlists/<playlist name>/`
  holds the audio files (`mp3 m4a aac wav flac`); the tracks of a playlist are
  whatever is in its folder, sorted by name. There is no database. Tracks get
  in three ways, all equivalent: the **+** on a playlist screen (file picker,
  copies the files in), the Files app (On My iPhone › Audio Player ›
  Playlists › …), or `tool/push_music.sh` from the Mac. The folders are
  re-read on launch and every time the app returns to the foreground.
- **First launch** creates `20 minute yoga nidra`, `40 minute yoga nidra`
  (both "one, then stop") and `HIIT music` ("keep going"). A flag in
  preferences (`seedVersion`) stops a deleted one from coming back.
- **Home screen**: one card per playlist. Tap the card to open it; the wave
  button opens the overlay sheet for that playlist; the shuffle button plays
  a random track from it straight away. A bar at the bottom shows the loaded
  track; tap it for the play screen.
- **Playlist screen**: Shuffle play, the overlay button, the shuffle setting,
  and the tracks. Tapping a track plays that specific track. **+** adds
  tracks; the ⋮ menus remove a track or delete the playlist (which deletes
  its files from the app).
- **Shuffle setting** (per playlist): *Play a random song, then stop* or
  *Continue playing songs at random*. It decides what happens whenever a
  track ends, whether that track was picked by the shuffle button or tapped
  by hand, and is read at that moment, so changing it mid-track works.
  "Continue" plays every track once before repeating any (`lib/shuffle.dart`).
  There is no play-in-order mode. Next = another random track; Previous =
  restart, or the track before if pressed in the first 3 seconds.
- **Overlay**: a second audio player looping `assets/overlays/pink_noise.wav`
  under the track, with its own volume slider. It sounds only while a track
  is playing: pausing pauses it, and when "one, then stop" reaches the end the
  noise stops too. The choice (off / pink noise) and volume are saved per
  playlist the moment they change, which is how each playlist remembers its
  overlay. Adding another overlay is one line in `overlays` in
  `lib/library.dart` plus a file in `assets/overlays/`.
- **Fewest taps for the two real uses** (nap: one random yoga nidra with
  pink noise; cardio intervals: shuffled music). Both are one tap on the
  playlist's shuffle button, because the shuffle setting and the overlay are
  already stored on the playlist; the yoga nidra playlists start with pink
  noise on. To skip opening the app as well, the link
  `audioplayer://shuffle?playlist=40%20minute%20yoga%20nidra` (any playlist
  name, case ignored, spaces as `%20`) does exactly what that button does.
  In the Shortcuts app, make a shortcut with one *Open URLs* action holding
  that link, then put it on the home screen, the Action button, a Back Tap,
  or say its name to Siri: one press from anywhere starts the nap or the
  workout.
- **Background**: `audio_service` + the `audio` background mode keep playback
  going with the screen locked and give lock-screen / headphone controls.
- **Drafts**: the only text field is the new-playlist name. It is saved on
  every keystroke under `draft.newPlaylistName`, restored when the dialog
  opens, and cleared only when the playlist is created. Spell check is on.
- **Even loudness** is not done in the app. `tool/normalize.py` makes
  loudness-matched copies on the Mac before they are pushed (see Common
  tasks). The seven yoga nidras differed by 16 dB before this.

Dependencies and why: `just_audio` (two players at once, looping, seeking),
`audio_service` + `audio_session` (background playback and lock-screen
controls), `file_picker` (adding tracks), `path_provider`,
`shared_preferences`, `app_links` (receives the `audioplayer://` link on both
platforms without native code).

## Files

| File | Purpose |
|---|---|
| `lib/main.dart` | Startup, globals (`library`, `player`, `prefs`), theme, rescan on resume, the `audioplayer://` link |
| `lib/library.dart` | Playlists as folders, per-playlist settings, the list of overlays |
| `lib/player.dart` | Track player + overlay player, what happens when a track ends, lock-screen state |
| `lib/shuffle.dart` | Random order without repeats |
| `lib/home_screen.dart` | Playlist cards, new-playlist dialog |
| `lib/playlist_screen.dart` | One playlist: tracks, add/remove, shuffle setting |
| `lib/play_screen.dart` | Now playing: seek bar, transport, overlay button |
| `lib/widgets.dart` | Overlay button + sheet, shuffle-setting picker, mini player |
| `assets/overlays/pink_noise.wav` | 60 s seamless pink-noise loop (made by `tool/gen_pink_noise.sh`) |
| `tool/push_music.sh` | Copy audio from the Mac into a playlist on the phone or simulator |
| `tool/normalize.py` | Make loudness-matched MP3 copies of a set of files |
| `tool/gen_pink_noise.sh` | Regenerate the pink-noise loop |
| `tool/gen_icon.swift` | Draw the app icon (waveform bars) at every iOS and Android size: `swift tool/gen_icon.swift` |
| `test/` | Unit tests: shuffle order, playlist folders and settings |
| `integration_test/app_test.dart` | End-to-end test on a simulator/phone with real audio |
| `ios-deploy.conf` | Opts in to `../ios-auto-deploy`: every commit is installed on the iPhone |

## Runtime locations

- On the phone: tracks in `Documents/Playlists/<name>/` inside the app's
  container (visible in the Files app); settings in the app's
  SharedPreferences (`playlist.<name>` = shuffle mode, overlay, overlay
  volume; `playlistOrder`; `seedVersion`; `draft.newPlaylistName`).
- On the Mac: loudness-matched copies in
  `~/Library/Application Support/AudioPlayer/normalized/<playlist>/`. The
  yoga nidra originals are in iCloud Drive › `Yoga Nidras` and are untouched.
- Bundle id `com.elityre.audioPlayer` (Android: `com.elityre.audio_player`).
- No log file; `debugPrint` output shows under `flutter run`.

## Common tasks

```bash
cd ~/Documents/agent-coding/audio-player

flutter test                                           # unit tests
flutter test integration_test -d "iPhone 17"           # end-to-end on the booted simulator (~20 s)
flutter run -d "iPhone 17"                             # run in the simulator

git commit ...                                         # that is the deploy: ios-auto-deploy installs it
python3 ../ios-auto-deploy/watch.py deploy audio-player   # or push HEAD to the phone right now

# Add music from the Mac: match loudness, then copy into a playlist
tool/normalize.py ~/Library/Application\ Support/AudioPlayer/normalized/"HIIT music" ~/Music/hiit/ --measure
tool/normalize.py ~/Library/Application\ Support/AudioPlayer/normalized/"HIIT music" ~/Music/hiit/ --target -16
tool/push_music.sh "HIIT music" ~/Library/Application\ Support/AudioPlayer/normalized/"HIIT music"
tool/push_music.sh --sim "HIIT music" some.mp3         # same, into the simulator

xcrun simctl openurl booted "audioplayer://shuffle?playlist=HIIT%20music"   # try the link (simulator asks to confirm)

flutter build apk --release                            # Android build (needs a JDK, see Gotchas)
```

`--measure` prints each file's loudness and peak first. Pick a `--target`
that no file reports as "limited by peak" (the yoga nidras use -26; loud
music can take about -16).

## Settings that matter

- iPhone paired with this Mac for `ios-auto-deploy` and `tool/push_music.sh`
  (see `../ios-auto-deploy/README.md`).
- `ios/Runner/Info.plist`: `UIBackgroundModes: audio` (play when locked),
  `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` (the playlists
  folder shows in the Files app).

## Gotchas learned

- `build/` is a symlink to `~/Library/Caches/flutter-builds/audio-player`.
  `~/Documents` is iCloud-synced and the attributes iCloud adds make codesign
  fail with "resource fork, Finder information, or similar detritus not
  allowed". After a fresh clone:
  `mkdir -p ~/Library/Caches/flutter-builds/audio-player && ln -s ~/Library/Caches/flutter-builds/audio-player build`.
- `flutter create` set the iOS deployment target to 13.0, which this Xcode
  refuses ("range of supported deployment target versions is 15.0 to …").
  It is 15.0 in `project.pbxproj`.
- `BaseAudioHandler` already has a `queue` member; a field of that name in
  the handler is a compile error. Ours is `files`.
- The pink-noise loop is a WAV on purpose: MP3 and AAC carry padding at both
  ends that would put a gap at every loop. The last 2 s are crossfaded into
  the first 2 s so the join is inaudible.
- Loudness matching uses one fixed gain per file, no compression. A quiet
  recording with a few loud peaks cannot be raised far without clipping,
  which is what caps the common level (-26 LUFS for the yoga nidras).
- `file_picker` with `FileType.audio` opens the Music library on iOS, not
  Files; the app uses `FileType.custom` with extensions instead.
- Android has never been built or run: this Mac has no Java runtime, so
  Gradle stops at "Unable to locate a Java Runtime". Install a JDK
  (`brew install --cask temurin`) before `flutter build apk`. The manifest
  entries for `audio_service` and the link are in place but untested.
- `xcrun simctl openurl` shows an "Open in Audio Player?" dialog that cannot
  be accepted from the command line, so delivery of the link by the OS is
  checked by hand; the integration test calls `handleLink` directly.
- `Info.plist` has `FlutterDeepLinkingEnabled = false` (and the Android
  manifest `flutter_deeplinking_enabled = false`): otherwise Flutter also
  tries to treat the link as a route name for the Navigator.
