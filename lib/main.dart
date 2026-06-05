import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'features/music/presentation/music_hub_screen.dart';
import 'features/music/presentation/music_providers.dart';
import 'core/di/injection.dart';
import 'features/music/data/plugins/plugin_manager.dart';
import 'features/player/data/audio_handler.dart';
import 'features/settings/data/torbox_settings_repository.dart';
import 'core/theme/apple_music_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/glassmorphism.dart';
import 'core/theme/apple_music_components.dart';
import 'features/player/presentation/mini_player.dart';
import 'features/player/presentation/player_providers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/share_handler_service.dart';

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
  
  if (!Platform.isLinux) {
    await Permission.notification.request();
  }
  
  if (Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized();
  }
  
  await configureInjection();
  await getIt<PluginManager>().init();


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

  runApp(const ProviderScope(child: MyApp()));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Isai',
      debugShowCheckedModeBanner: false,
      theme: AppleMusicTheme.lightTheme(),
      darkTheme: AppleMusicTheme.darkTheme(),
      themeMode: themeMode,
      home: const AppGate(),
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
                    color: AppleMusicTheme.primaryPink,
                  ),
                ),
                const SizedBox(height: 32),
                AppleMusicGradientText(
                  text: 'Isai',
                  fontSize: 32,
                  colors: isDark 
                      ? [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple]
                      : [Colors.white, Colors.white],
                ),
                const SizedBox(height: 8),
                Text(
                  'Powered by TorBox',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.white70,
                  ),
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
                              style: TextStyle(
                                color: isDark 
                                    ? AppleMusicTheme.primaryPink.withOpacity(0.8) 
                                    : AppleMusicTheme.primaryPink,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
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
                              AppleMusicTheme.primaryPink,
                              AppleMusicTheme.primaryPurple,
                            ],
                          ),
                          child: settings.isValidating
                              ? const Row(
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
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Connect',
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
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
                          style: TextStyle(
                            color: AppleMusicTheme.primaryPink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
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
