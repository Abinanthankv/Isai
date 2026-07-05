import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'youtube_test_screen.dart';

void main() {
  MediaKit.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  runApp(MaterialApp(
    title: 'YouTube Test',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData.dark(useMaterial3: true),
    home: const YoutubeTestScreen(),
  ));
}
