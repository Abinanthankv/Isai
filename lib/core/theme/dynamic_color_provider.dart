import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import '../../main.dart';

class DynamicColorState {
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  final String? currentArtworkUrl;
  final bool hasExtractedColors;

  DynamicColorState({
    required this.lightScheme,
    required this.darkScheme,
    this.currentArtworkUrl,
    this.hasExtractedColors = true,
  });

  factory DynamicColorState.defaultTheme() {
    return DynamicColorState(
      lightScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      darkScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
      hasExtractedColors: false,
    );
  }
}

class DynamicColorNotifier extends Notifier<DynamicColorState> {
  // Simple in-memory cache for extracted schemes
  static final Map<String, DynamicColorState> _cache = {};

  @override
  DynamicColorState build() {
    final mediaItemAsync = ref.watch(playerMediaItemProvider);
    final mediaItem = mediaItemAsync.value;
    final artUri = mediaItem?.artUri;

    if (artUri == null) {
      return DynamicColorState.defaultTheme();
    }

    final artUrlStr = artUri.toString();

    // If it's cached, return it immediately
    if (_cache.containsKey(artUrlStr)) {
      return _cache[artUrlStr]!;
    }

    // Otherwise, start extracting asynchronously and return default/current state for now
    _extractColors(artUri);
    return stateOrNull ?? DynamicColorState.defaultTheme();
  }

  DynamicColorState? get stateOrNull {
    try {
      return state;
    } catch (_) {
      return null;
    }
  }

  Future<void> _extractColors(Uri uri) async {
    final urlStr = uri.toString();
    try {
      ImageProvider imageProvider;
      if (uri.scheme == 'file') {
        imageProvider = FileImage(File(uri.toFilePath()));
      } else {
        imageProvider = CachedNetworkImageProvider(urlStr);
      }

      final lightScheme = await ColorScheme.fromImageProvider(
        provider: imageProvider,
        brightness: Brightness.light,
      );
      final darkScheme = await ColorScheme.fromImageProvider(
        provider: imageProvider,
        brightness: Brightness.dark,
      );

      final newState = DynamicColorState(
        lightScheme: lightScheme,
        darkScheme: darkScheme,
        currentArtworkUrl: urlStr,
      );

      _cache[urlStr] = newState;

      // Only update state if the artwork we processed is still the current one
      final currentMediaItem = ref.read(playerMediaItemProvider).value;
      if (currentMediaItem?.artUri?.toString() == urlStr) {
        state = newState;
      }
    } catch (e) {
      print('[DynamicColorProvider] Error extracting color scheme: $e');
      // If error occurs, put a default theme in cache for this URL to avoid spamming errors
      final fallbackState = DynamicColorState(
        lightScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        darkScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        currentArtworkUrl: urlStr,
      );
      _cache[urlStr] = fallbackState;
      
      final currentMediaItem = ref.read(playerMediaItemProvider).value;
      if (currentMediaItem?.artUri?.toString() == urlStr) {
        state = fallbackState;
      }
    }
  }
}

final dynamicColorProvider = NotifierProvider<DynamicColorNotifier, DynamicColorState>(() {
  return DynamicColorNotifier();
});
