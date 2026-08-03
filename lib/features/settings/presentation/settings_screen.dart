import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../music/presentation/music_providers.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../music/presentation/stats_screen.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:url_launcher/url_launcher.dart';
import '../../music/presentation/lastfm_provider.dart';
import '../../music/presentation/player_customization_screen.dart';
import '../../music/presentation/discover_customization_screen.dart';
import 'plugin_management_screen.dart';
import 'storage_settings_screen.dart';
import 'lastfm_settings_screen.dart';
import 'eclipse_screen.dart';
import 'package:dio/dio.dart';
import 'package:isai/core/updater/app_updater.dart';




class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  late TextEditingController _apiKeyController;
  static const String _localVersion = '1.0.0';
  String _currentLocalVersion = _localVersion;
  String _githubVersion = _localVersion;
  String _changelog = '';
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(settingsProvider).apiKey;
    _apiKeyController = TextEditingController(text: existing);
    WidgetsBinding.instance.addObserver(this);
    _fetchGithubVersion();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final lastfm = ref.read(lastfmProvider);
      if (lastfm.isConnecting && lastfm.hasPendingToken) {
        print('[SettingsScreen] App resumed with pending Last.fm token. Finalizing setup...');
        ref.read(lastfmProvider.notifier).completeConnection();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            centerTitle: false,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: AppleMusicGradientText(
                text: 'Settings',
                fontSize: 28,
                colors: isDark
                    ? [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]
                    : [const Color(0xFF667eea), const Color(0xFF764ba2)],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  
                  AppleMusicSectionHeader(title: 'Appearance & Personalization'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.brightness_6_outlined,
                          title: 'Theme',
                          subtitle: _getThemeLabel(themeMode),
                          onTap: () => _showThemePicker(context, ref, themeMode),
                        ),
                        const Divider(height: 1, indent: 52),
                        _SettingsTile(
                          icon: Icons.style_outlined,
                          title: 'Theme Style',
                          subtitle: settings.appThemeStyle == 'apple' ? 'Apple Music' : 'Google Material 3',
                          onTap: () => _showThemeStylePicker(context, ref, settings),
                        ),
                        const Divider(height: 1, indent: 52),
                        _SettingsTile(
                          icon: Icons.font_download_outlined,
                          title: 'Font Style',
                          subtitle: settings.appFontFamily,
                          onTap: () => _showFontStylePicker(context, ref, settings),
                        ),
                        const Divider(height: 1, indent: 52),
                        _SettingsTile(
                          icon: Icons.palette_outlined,
                          title: 'Customize Player',
                          subtitle: 'Artwork shape, background & glow',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerCustomizationScreen())),
                        ),
                        const Divider(height: 1, indent: 52),
                        _SettingsTile(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Customize Discover Screen',
                          subtitle: 'Reorder & toggle Discover sections',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverCustomizationScreen())),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  AppleMusicSectionHeader(title: 'Account & Integrations'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.key,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'TorBox API Key',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              TextField(
                                controller: _apiKeyController,
                                obscureText: true,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'API Key',
                                  labelStyle: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.vpn_key,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (settings.isValid) 
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(
                                            Icons.check_circle, 
                                            color: Colors.greenAccent,
                                            size: 20,
                                          ),
                                        ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.open_in_new,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                          size: 22,
                                        ),
                                        onPressed: () async {
                                          final url = Uri.parse('https://torbox.app/settings?section=account');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        tooltip: 'Open TorBox Settings',
                                      ),
                                    ],
                                  ),
                                  filled: true,
                                  fillColor: isDark 
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              if (settings.error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  settings.error!,
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: GlassButton(
                                  onPressed: settings.isValidating
                                      ? null
                                      : () => ref
                                          .read(settingsProvider.notifier)
                                          .saveAndValidateApiKey(
                                              _apiKeyController.text.trim()),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
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
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Validating...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Save & Validate',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (settings.apiKey != null && settings.apiKey!.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      _apiKeyController.clear();
                                      ref.read(settingsProvider.notifier).clearApiKey();
                                    },
                                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                                    label: const Text(
                                      'Clear API Key', 
                                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: () async {
                                    final url = Uri.parse('https://torbox.app');
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
                              ),
                              const SizedBox(height: 8),
                              _SettingsTile(
                                icon: Icons.dashboard_outlined,
                                title: 'TorBox Dashboard',
                                subtitle: 'Manage your torrents and account',
                                onTap: () async {
                                  final url = Uri.parse('https://torbox.app/dashboard');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                        _LastfmLoginSection(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  AppleMusicSectionHeader(title: 'Eclipse'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: const _EclipseSettingsSection(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  AppleMusicSectionHeader(title: 'Data & Storage'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.storage_rounded,
                          title: 'Storage',
                          subtitle: 'Manage downloaded songs and cache limits',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageSettingsScreen())),
                        ),
                        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                        if (settings.downloadFolders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.folder_off_outlined, color: isDark ? Colors.white24 : Colors.black26, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No download folders added',
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...settings.downloadFolders.map((folder) {
                            final isSelected = settings.selectedDownloadFolder == folder;
                            return Column(
                              children: [
                                _SettingsFolderTile(
                                  path: folder,
                                  isSelected: isSelected,
                                  onSelect: () {
                                    ref.read(settingsProvider.notifier).setSelectedDownloadFolder(folder);
                                  },
                                  onRemove: () {
                                    ref.read(settingsProvider.notifier).removeDownloadFolder(folder);
                                  },
                                ),
                                if (folder != settings.downloadFolders.last)
                                  Divider(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                    height: 1,
                                    indent: 56,
                                  ),
                              ],
                            );
                          }),
                        
                        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                        
                        _SettingsTile(
                          icon: Icons.add_to_photos_outlined,
                          title: 'Add Download Folder',
                          subtitle: 'Select a directory to save songs',
                          onTap: () => _pickDownloadFolder(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  AppleMusicSectionHeader(title: 'Audiobooks'),

                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (settings.audiobookFolder != null && settings.audiobookFolder!.isNotEmpty) ...[
                          _SettingsFolderTile(
                            path: settings.audiobookFolder!,
                            isSelected: true,
                            onSelect: () {}, // Already selected (single folder)
                            onRemove: () {
                              ref.read(settingsProvider.notifier).removeAudiobookFolder();
                            },
                          ),
                          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                          _SettingsTile(
                            icon: Icons.folder_open_outlined,
                            title: 'Change Audiobooks Folder',
                            subtitle: 'Pick a different directory',
                            onTap: () => _pickAudiobookFolder(),
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.library_books_outlined, color: isDark ? Colors.white24 : Colors.black26, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No audiobook folder set',
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add a folder containing audiobook subfolders',
                                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                          _SettingsTile(
                            icon: Icons.create_new_folder_outlined,
                            title: 'Set Audiobooks Folder',
                            subtitle: 'Select your local audiobooks directory',
                            onTap: () => _pickAudiobookFolder(),
                          ),
                        ],
                        Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                        const _HardcoverSettingsSection(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  AppleMusicSectionHeader(title: 'Tools & Advanced'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.bar_chart_rounded,
                          title: 'Stats',
                          subtitle: 'View your listening habits',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                        ),
                        const Divider(height: 1, indent: 52),
                        _SettingsTile(
                          icon: Icons.extension_outlined,
                          title: 'Addon Manager',
                          subtitle: 'Manage and test JS source plugins',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginManagementScreen())),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  
                  AppleMusicSectionHeader(title: 'About'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.info_outline,
                          title: _updateAvailable ? 'New Update Available!' : 'Version',
                          subtitle: _updateAvailable ? 'v$_githubVersion (Local: v$_currentLocalVersion)' : 'v$_currentLocalVersion',
                          showChevron: true,
                          onTap: () => AppUpdater.checkForUpdate(context, silent: false),
                        ),
                        _SettingsTile(
                          icon: Icons.history_rounded,
                          title: 'Changelog',
                          subtitle: 'View release notes',
                          onTap: () => _showChangelogDialog(context),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDownloadFolder() async {
    try {
      if (io.Platform.isAndroid) {
        // For Android 11+, we ideally need MANAGE_EXTERNAL_STORAGE for arbitrary folders
        // But let's start with basic storage permissions.
        var status = await Permission.storage.request();
        if (status.isPermanentlyDenied) {
          openAppSettings();
          return;
        }
        
        // Also check manageExternalStorage for Android 11+
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }

      String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        await ref.read(settingsProvider.notifier).addDownloadFolder(selectedDirectory);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick folder: $e')),
        );
      }
    }
  }

  Future<void> _pickAudiobookFolder() async {
    try {
      if (io.Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (status.isPermanentlyDenied) {
          openAppSettings();
          return;
        }
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }

      String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        await ref.read(settingsProvider.notifier).setAudiobookFolder(selectedDirectory);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick folder: $e')),
        );
      }
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Theme',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,),
            ),
            const SizedBox(height: 20),
            _ThemeOption(
              icon: Icons.brightness_auto,
              title: 'System',
              isSelected: currentMode == ThemeMode.system,
              onTap: () {
                ref.read(themeProvider.notifier).setTheme(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.light_mode,
              title: 'Light',
              isSelected: currentMode == ThemeMode.light,
              onTap: () {
                ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode,
              title: 'Dark',
              isSelected: currentMode == ThemeMode.dark,
              onTap: () {
                ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _isUpdateAvailable(String local, String latest) {
    try {
      final localParts = local.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      for (int i = 0; i < latestParts.length; i++) {
        final latestPart = latestParts[i];
        final localPart = i < localParts.length ? localParts[i] : 0;
        if (latestPart > localPart) return true;
        if (latestPart < localPart) return false;
      }
    } catch (_) {
      return local != latest;
    }
    return false;
  }

  Future<void> _fetchGithubVersion() async {
    try {
      final response = await Dio().get('https://api.github.com/repos/Abinanthankv/Isai/releases/latest');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final tag = data['tag_name']?.toString() ?? '1.0.0';
        final cleanTag = tag.replaceAll('v', '');
        final body = data['body']?.toString() ?? '';
        
        // Extract direct APK URL
        String? apkUrl;
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk') && !name.contains('arm') && !name.contains('x86')) {
            apkUrl = asset['browser_download_url']?.toString();
            break;
          }
        }
        if (apkUrl == null && assets.isNotEmpty) {
          for (final asset in assets) {
            final name = asset['name']?.toString() ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url']?.toString();
              break;
            }
          }
        }

        // Retrieve local version dynamically
        String localVer = _localVersion;
        try {
          if (io.Platform.isAndroid) {
            final channel = MethodChannel('com.isai.music/updater');
            localVer = await channel.invokeMethod<String>('getAppVersion') ?? _localVersion;
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _currentLocalVersion = localVer;
            _githubVersion = cleanTag;
            _updateAvailable = _isUpdateAvailable(localVer, cleanTag);
            if (body.isNotEmpty) {
              _changelog = body;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<String> _fetchChangelog() async {
    if (_changelog.isNotEmpty) return _changelog;
    try {
      final response = await Dio().get('https://api.github.com/repos/Abinanthankv/Isai/releases/latest');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final body = data['body']?.toString();
        if (body != null && body.isNotEmpty) {
          _changelog = body;
          return _changelog;
        }
      }
    } catch (_) {}

    try {
      final response = await Dio().get('https://raw.githubusercontent.com/Abinanthankv/Isai/main/CHANGELOG.md');
      if (response.statusCode == 200 && response.data != null) {
        _changelog = response.data.toString();
        return _changelog;
      }
    } catch (_) {}

    return 'Could not load changelog. Please check your internet connection.';
  }

  void _showChangelogDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Changelog',
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: FutureBuilder<String>(
              future: _fetchChangelog(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  );
                }
                final text = snapshot.data ?? 'Could not load changelog. Please check your internet connection.';
                return SingleChildScrollView(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'monospace',),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _showThemeStylePicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textStyle = TextStyle(color: textColor, fontWeight: FontWeight.bold);
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;
    final subtitleStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: subtitleColor,);
    final labelColor = isDark ? Colors.white70 : Colors.black87;

    Widget _buildColorSwatch(BuildContext context, String label, Color color, bool isDark) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,),
          ),
        ],
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentSettings = ref.watch(settingsProvider);
          return GlassContainer(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Style',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                    color: textColor,),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Icons.phone_iphone_rounded,
                    color: currentSettings.appThemeStyle == 'apple' ? Theme.of(context).colorScheme.primary : subtitleColor,
                  ),
                  title: Text('Apple Music', style: textStyle),
                  subtitle: Text('Acrylic glassmorphism & classic pink aesthetics', style: subtitleStyle),
                  trailing: currentSettings.appThemeStyle == 'apple' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setAppThemeStyle('apple');
                    setModalState(() {});
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.android_rounded,
                    color: currentSettings.appThemeStyle == 'material3' ? Theme.of(context).colorScheme.primary : subtitleColor,
                  ),
                  title: Text('Google Material 3 (Expressive)', style: textStyle),
                  subtitle: Text('Dynamic artwork-based colors with expressive shapes', style: subtitleStyle),
                  trailing: currentSettings.appThemeStyle == 'material3' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setAppThemeStyle('material3');
                    setModalState(() {});
                  },
                ),
                if (currentSettings.appThemeStyle == 'material3') ...[
                  Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'DYNAMIC PALETTE PREVIEW',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildColorSwatch(context, 'Primary', Theme.of(context).colorScheme.primary, isDark),
                        _buildColorSwatch(context, 'Secondary', Theme.of(context).colorScheme.secondary, isDark),
                        _buildColorSwatch(context, 'Tertiary', Theme.of(context).colorScheme.tertiary, isDark),
                        _buildColorSwatch(context, 'Container', Theme.of(context).colorScheme.primaryContainer, isDark),
                      ],
                    ),
                  ),
                ],
                if (currentSettings.appThemeStyle == 'apple') ...[
                  Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'APPLE DESIGN OPTIONS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                  SwitchListTile(
                    title: Text('Liquid Glass Backgrounds', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor,)),
                    subtitle: Text('Animated mesh gradient for mini player & nav bar', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: subtitleColor,)),
                    value: currentSettings.appleUseLiquidGlass,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).setAppleUseLiquidGlass(val);
                      setModalState(() {});
                    },
                  ),
                  if (currentSettings.appleUseLiquidGlass) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Background Opacity',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: labelColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Icon(Icons.opacity, color: subtitleColor, size: 20),
                          Expanded(
                            child: Slider(
                              min: 0.0,
                              max: 1.0,
                              value: currentSettings.appleLiquidGlassOpacity,
                              activeColor: Theme.of(context).colorScheme.primary,
                              inactiveColor: isDark ? Colors.white12 : Colors.black12,
                              onChanged: (val) {
                                ref.read(settingsProvider.notifier).setAppleLiquidGlassOpacity(val);
                                setModalState(() {});
                              },
                            ),
                          ),
                          Text(
                            '${(currentSettings.appleLiquidGlassOpacity * 100).toInt()}%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: labelColor, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFontStylePicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final textStyle = TextStyle(color: textColor, fontWeight: FontWeight.bold);
    
    final fonts = [
      'Roboto Flex',
      'Inter',
      'Roboto Mono',
      'Noto Sans',
      'Outfit'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentSettings = ref.watch(settingsProvider);
          return GlassContainer(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font Style',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                    color: textColor,),
                ),
                const SizedBox(height: 16),
                
                // Real-time Preview Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Typography Preview',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The quick brown fox jumps over the lazy dog.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1234567890 • !@#\$%^&*()',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black54,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Font List
                ...fonts.map((font) => ListTile(
                  title: Text(font, style: textStyle.copyWith(fontFamily: font)),
                  trailing: currentSettings.appFontFamily == font 
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) 
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setAppFontFamily(font);
                    setModalState(() {});
                  },
                )),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}


class _SettingsFolderTile extends StatelessWidget {
  final String path;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _SettingsFolderTile({
    required this.path,
    required this.isSelected,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderName = path.split(io.Platform.pathSeparator).last;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.folder_outlined,
                color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white54 : Colors.black45),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,),
                    ),
                    Text(
                      path,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white : Colors.black,),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
            activeTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _HardcoverSettingsSection extends ConsumerStatefulWidget {
  const _HardcoverSettingsSection();
  @override
  ConsumerState<_HardcoverSettingsSection> createState() => _HardcoverSettingsSectionState();
}

class _HardcoverSettingsSectionState extends ConsumerState<_HardcoverSettingsSection> {
  late TextEditingController _hcController;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(settingsProvider).hardcoverApiKey;
    _hcController = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _hcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (settings.hardcoverUsername != null) {
      return Column(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Logged in as ${settings.hardcoverUsername}',
            subtitle: 'Hardcover connected',
            showChevron: false,
          ),
          const Divider(height: 1, indent: 48),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Disconnect Hardcover',
            subtitle: 'Remove API token',
            onTap: () {
              _hcController.clear();
              ref.read(settingsProvider.notifier).clearHardcoverKey();
            },
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Connect Hardcover',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Track your currently reading books and sync reading progress.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hcController,
            obscureText: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Bearer Token',
              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
              prefixIcon: Icon(Icons.vpn_key, color: isDark ? Colors.white54 : Colors.black45),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (settings.hardcoverError != null) ...[
            const SizedBox(height: 8),
            Text(settings.hardcoverError!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              onPressed: settings.hardcoverIsValidating
                  ? null
                  : () => ref
                      .read(settingsProvider.notifier)
                      .saveAndValidateHardcoverKey(_hcController.text.trim()),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  AppleMusicTheme.primaryPurple,
                ],
              ),
              child: settings.hardcoverIsValidating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Validating...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : const Text('Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Get your token at hardcover.app/settings',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _LastfmLoginSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastfm = ref.watch(lastfmProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (lastfm.isConnected) {
      return _SettingsTile(
        icon: Icons.music_note_rounded,
        title: 'Last.fm',
        subtitle: 'Connected as ${lastfm.username}',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LastfmSettingsScreen())),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text('Connect Last.fm',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Keep track of every song you listen to and sync your history with Last.fm.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87)),
          if (lastfm.error != null) ...[
            const SizedBox(height: 12),
            Text(lastfm.error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed: lastfm.isConnecting
                      ? null
                      : () => ref.read(lastfmProvider.notifier).connect(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: lastfm.isConnecting
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Connect'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  onPressed: lastfm.isConnecting
                      ? null
                      : () => ref.read(lastfmProvider.notifier).completeConnection(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
                  ),
                  child: const Text('Finish Setup',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('1. Tap Connect -> 2. Approve in browser -> 3. Tap Finish',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.black38)),
          ),
        ],
      ),
    );
  }
}

class _EclipseSettingsSection extends ConsumerStatefulWidget {
  const _EclipseSettingsSection();
  @override
  ConsumerState<_EclipseSettingsSection> createState() => _EclipseSettingsSectionState();
}

class _EclipseSettingsSectionState extends ConsumerState<_EclipseSettingsSection> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (settings.eclipseIsValid) {
      return _SettingsTile(
        icon: Icons.cloud,
        title: 'Eclipse',
        subtitle: settings.eclipseUsername ?? 'Connected',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EclipseAccountScreen())),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Connect Eclipse',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Sync your playlists and listen history across devices.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.white54 : Colors.black45),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                    prefixIcon: Icon(Icons.lock_outlined, color: isDark ? Colors.white54 : Colors.black45),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (settings.eclipseError != null) ...[
            const SizedBox(height: 8),
            Text(settings.eclipseError!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              onPressed: settings.eclipseIsValidating
                  ? null
                  : () => ref
                      .read(settingsProvider.notifier)
                      .eclipseLogin(_emailController.text.trim(), _passwordController.text),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  AppleMusicTheme.primaryPurple,
                ],
              ),
              child: settings.eclipseIsValidating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Connecting...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : const Text('Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
