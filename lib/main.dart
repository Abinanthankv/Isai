import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'features/music/presentation/music_hub_screen.dart';
import 'features/music/presentation/music_providers.dart';
import 'core/di/injection.dart';
import 'features/music/data/plugins/plugin_manager.dart';
import 'features/player/data/audio_handler.dart';
import 'features/settings/data/torbox_settings_repository.dart';
import 'core/theme/apple_music_theme.dart';
import 'core/theme/material3_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/glassmorphism.dart';
import 'core/theme/apple_music_components.dart';
import 'features/player/presentation/mini_player.dart';
import 'features/player/presentation/player_providers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/share_handler_service.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show LiquidGlassWidgets;
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'core/theme/dynamic_color_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

late AudioHandler audioHandler;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  print('[HttpOverrides] Bypassing SSL certificate verification for diagnostics');
  
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
      print('[FlutterDisplayMode] High refresh rate mode enabled successfully');
    } catch (e) {
      print('[FlutterDisplayMode] Failed to set high display refresh rate: $e');
    }
  }

  if (!Platform.isLinux) {
    Permission.notification.request();
  }
  
  if (Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized();
  }
  
  MediaKit.ensureInitialized();
  
  await configureInjection();
  await getIt<PluginManager>().init();

  await LiquidGlassWidgets.initialize();

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.isai.music.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_music',
    ),
  );

  ShareHandlerService.init();

  runApp(LiquidGlassWidgets.wrap(child: const ProviderScope(child: MyApp())));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final appThemeStyle = ref.watch(settingsProvider).appThemeStyle;
    final appFontFamily = ref.watch(settingsProvider).appFontFamily;
    final dynamicColors = ref.watch(dynamicColorProvider);
    
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme = dynamicColors.lightScheme;
        ColorScheme darkScheme = dynamicColors.darkScheme;

        // If M3 theme is used and we don't have artwork colors, use system dynamic colors if available
        if (appThemeStyle == 'material3' && !dynamicColors.hasExtractedColors) {
          if (lightDynamic != null) {
            lightScheme = lightDynamic.harmonized();
          }
          if (darkDynamic != null) {
            darkScheme = darkDynamic.harmonized();
          }
        }

        final lightTheme = appThemeStyle == 'material3'
            ? Material3Theme.lightThemeFromScheme(lightScheme, fontFamily: appFontFamily)
            : AppleMusicTheme.lightTheme(fontFamily: appFontFamily);
            
        final darkTheme = appThemeStyle == 'material3'
            ? Material3Theme.darkThemeFromScheme(darkScheme, fontFamily: appFontFamily)
            : AppleMusicTheme.darkTheme(fontFamily: appFontFamily);

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Isai',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOut,
          home: const AppGate(),
        );
      },
    );
  }
}


// I should probably use a simpler way to watch mediaItem in a ConsumerWidget
final playerMediaItemProvider = StreamProvider<MediaItem?>((ref) => audioHandler.mediaItem);


class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Allow entry even without API key as requested
    return const MusicHubScreen();
  }
}

class _SetupScreen extends ConsumerStatefulWidget {
  const _SetupScreen();

  @override
  ConsumerState<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<_SetupScreen> {
  final _controller = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (settings.isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MusicHubScreen()),
        );
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f3460),
                  ]
                : [
                    const Color(0xFF667eea),
                    const Color(0xFF764ba2),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(30),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                AppleMusicGradientText(
                  text: 'Isai',
                  fontSize: 32,
                  colors: isDark 
                      ? [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]
                      : [Colors.white, Colors.white],
                ),
                const SizedBox(height: 8),
                Text(
                  'Powered by TorBox',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white60 : Colors.white70,),
                ),
                const Spacer(),
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        obscureText: _obscureText,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'TorBox API Key',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.key,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: isDark 
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          helper: GestureDetector(
                            onTap: () async {
                              final url = Uri.parse('https://torbox.app/settings?section=account');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text(
                              'Find at torbox.app → Account → API Keys',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark 
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.8) 
                                    : Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,),
                            ),
                          ),
                        ),
                      ),
                      if (settings.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          settings.error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: GlassButton(
                          onPressed: settings.isValidating
                              ? null
                              : () => ref
                                  .read(settingsProvider.notifier)
                                  .saveAndValidateApiKey(_controller.text.trim()),
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              AppleMusicTheme.primaryPurple,
                            ],
                          ),
                          child: settings.isValidating
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white, 
                                        strokeWidth: 2
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Connecting...',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                                        color: Colors.white,),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Connect',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                                        color: Colors.white,),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const MusicHubScreen()),
                          );
                        },
                        child: Text(
                          'Enter without API Key',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          final url = Uri.parse('https://torbox.app/register');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          'Don\'t have an account? Sign up',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
