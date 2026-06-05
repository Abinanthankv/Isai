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
import 'plugin_management_screen.dart';
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
                    ? [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple]
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
                  
                  AppleMusicSectionHeader(title: 'Appearance'),
                  
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
                          icon: Icons.bar_chart_rounded,
                          title: 'Stats',
                          subtitle: 'View your listening habits',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
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
                          icon: Icons.extension_outlined,
                          title: 'Addon Manager',
                          subtitle: 'Manage and test JS source plugins',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginManagementScreen())),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  AppleMusicSectionHeader(title: 'Account'),
                  
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
                                    color: AppleMusicTheme.primaryPink,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'TorBox API Key',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
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
                                      : const Text(
                                          'Save & Validate',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                    style: TextStyle(
                                      color: AppleMusicTheme.primaryPink,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
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
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  AppleMusicSectionHeader(title: 'Last.fm Scrobbling'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: const _LastfmSettingsSection(),
                  ),
                  
                  const SizedBox(height: 24),


                  
                  AppleMusicSectionHeader(title: 'Downloads'),
                  
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
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
                  return const Center(
                    child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
                  );
                }
                final text = snapshot.data ?? 'Could not load changelog. Please check your internet connection.';
                return SingleChildScrollView(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppleMusicTheme.primaryPink)),
            ),
          ],
        );
      },
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
                color: isSelected ? AppleMusicTheme.primaryPink : (isDark ? Colors.white54 : Colors.black45),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      path,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
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
                color: AppleMusicTheme.primaryPink,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
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
                    ? AppleMusicTheme.primaryPink 
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppleMusicTheme.primaryPink,
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
            color: AppleMusicTheme.primaryPink,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppleMusicTheme.primaryPink,
            activeTrackColor: AppleMusicTheme.primaryPink.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _LastfmSettingsSection extends ConsumerWidget {
  const _LastfmSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastfm = ref.watch(lastfmProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (lastfm.isConnected) {
      return Column(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Logged in as ${lastfm.username}',
            subtitle: 'Scrobbling is active',
            showChevron: false,
          ),
          const Divider(height: 1, indent: 48),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Disconnect Last.fm',
            subtitle: 'Stop scrobbling to this account',
            onTap: () => ref.read(lastfmProvider.notifier).disconnect(),
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
                Icons.music_note_rounded,
                color: AppleMusicTheme.primaryPink,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Connect Last.fm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Keep track of every song you listen to and sync your history with Last.fm.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          if (lastfm.error != null) ...[
            const SizedBox(height: 12),
            Text(
              lastfm.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed: lastfm.isConnecting 
                        ? null 
                        : () => ref.read(lastfmProvider.notifier).connect(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: lastfm.isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
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
                      colors: [
                        AppleMusicTheme.primaryPink,
                        AppleMusicTheme.primaryPurple,
                      ],
                    ),
                    child: const Text(
                      'Finish Setup',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '1. Tap Connect -> 2. Approve in browser -> 3. Tap Finish',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
