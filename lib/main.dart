// Audio Player: an MP3 player built around playlists. Each playlist has a
// shuffle button with its own shuffle mode (one random song then stop, or
// keep going at random) and remembers the overlay (pink noise) last used
// with it.
//
// Where things live on the device:
//   tracks    <app Documents>/Playlists/<playlist name>/*.mp3  (see library.dart)
//   settings  SharedPreferences: "playlist.<name>", "playlistOrder", "draft.*"
//   logs      debugPrint only (visible in `flutter run` / Console.app)
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'library.dart';
import 'player.dart';

late final Library library;
late final PlayerHandler player;
late final SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  final docs = await getApplicationDocumentsDirectory();
  library = Library(Directory('${docs.path}/Playlists'), prefs)..init();
  player = await AudioService.init(
    builder: () => PlayerHandler(library),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.elityre.audio_player.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const AudioPlayerApp());
}

class AudioPlayerApp extends StatefulWidget {
  const AudioPlayerApp({super.key});

  @override
  State<AudioPlayerApp> createState() => _AudioPlayerAppState();
}

class _AudioPlayerAppState extends State<AudioPlayerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Tracks may have been dropped into a playlist folder through the Files
  // app while we were in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) library.rescan();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE58FB1), // pink, after the noise
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
