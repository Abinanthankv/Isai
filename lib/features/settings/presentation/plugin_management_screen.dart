import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../music/data/plugins/plugin_manager.dart';
import '../../music/data/plugins/js_plugin.dart';
import '../../../core/di/injection.dart';
import '../../music/data/music_models.dart';
import '../../music/presentation/now_playing_screen.dart';
import '../../music/presentation/music_providers.dart';
import 'package:isai/main.dart';

class PluginManagementScreen extends ConsumerStatefulWidget {
  const PluginManagementScreen({super.key});

  @override
  ConsumerState<PluginManagementScreen> createState() => _PluginManagementScreenState();
}

class _PluginManagementScreenState extends ConsumerState<PluginManagementScreen> {
  final _pluginManager = getIt<PluginManager>();
  final _urlController = TextEditingController();
  final _searchController = TextEditingController();
  
  bool _isInstalling = false;
  bool _isTesting = false;
  List<ScraperResult> _testResults = [];
  String? _selectedTestPlugin;
  bool _isLoadingFeatured = false;
  List<Map<String, String>> _featuredPluginsList = [];

  @override
  void initState() {
    super.initState();
    _refreshPlugins();
    _fetchFeaturedPlugins();
  }

  Future<void> _fetchFeaturedPlugins() async {
    if (mounted) {
      setState(() {
        _isLoadingFeatured = true;
      });
    }
    try {
      final list = await _pluginManager.fetchFeaturedPluginsFromRepo();
      if (mounted) {
        setState(() {
          _featuredPluginsList = list;
        });
      }
    } catch (e) {
      print('Failed to fetch featured plugins: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFeatured = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshPlugins() async {
    // Also clear the flac search cache so disabled scrapers don't return cached results
    ref.read(flacSearchProvider.notifier).clearCache();
    await _pluginManager.loadPlugins();
    if (mounted) setState(() {});
  }

  Future<void> _installPlugin(String url) async {
    if (url.trim().isEmpty) return;
    setState(() {
      _isInstalling = true;
    });

    try {
      final inputUrl = url.trim();
      String installedName = '';

      if (inputUrl.endsWith('.js')) {
        // Explicitly a JS plugin
        final plugin = await _pluginManager.installPluginFromUrl(inputUrl);
        installedName = plugin.name;
      } else {
        // Try Eclipse Addon first, if it fails, try JS Plugin
        try {
          final addon = await _pluginManager.installEclipseAddon(inputUrl);
          installedName = addon.name;
        } catch (e) {
          print('Failed as Eclipse addon, trying as JS plugin... $e');
          final plugin = await _pluginManager.installPluginFromUrl(inputUrl);
          installedName = plugin.name;
        }
      }

      _urlController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully installed: $installedName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to install addon: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
        _refreshPlugins();
      }
    }
  }

  Future<void> _testPluginSearch() async {
    final query = _searchController.text.trim();
    final pluginId = _selectedTestPlugin;
    if (query.isEmpty || pluginId == null) return;

    setState(() {
      _isTesting = true;
      _testResults = [];
    });

    try {
      List<ScraperResult> results;
      if (pluginId.startsWith('eclipse_')) {
        results = await _pluginManager.searchEclipse(pluginId.replaceFirst('eclipse_', ''), query);
      } else {
        results = await _pluginManager.search(pluginId, query);
      }
      if (mounted) {
        setState(() {
          _testResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final installedJs = _pluginManager.plugins;
    final installedEclipse = _pluginManager.eclipseAddons;
    
    final priority = ref.watch(settingsProvider).addonPriority;
    final allItems = <dynamic>[...installedJs, ...installedEclipse];
    allItems.sort((a, b) {
      final idA = a is JsPlugin ? a.id : 'eclipse_${a.id}';
      final idB = b is JsPlugin ? b.id : 'eclipse_${b.id}';
      int idxA = priority.indexOf(idA);
      int idxB = priority.indexOf(idB);
      if (idxA == -1) idxA = 999999;
      if (idxB == -1) idxB = 999999;
      return idxA.compareTo(idxB);
    });

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Colors.black, Color(0xFF120816)]
              : const [Color(0xFFF5F5F7), Color(0xFFF6F0FA)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Addon Manager',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Install from URL Section
            AppleMusicSectionHeader(title: 'Install External Plugin'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter a raw JS plugin file URL hosted on GitHub or any server.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87,),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'https://raw.githubusercontent.com/...',
                      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton(
                      onPressed: _isInstalling ? null : () => _installPlugin(_urlController.text),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          AppleMusicTheme.primaryPurple,
                        ],
                      ),
                      child: _isInstalling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Install Plugin',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Curated / Featured Gallery
            AppleMusicSectionHeader(title: 'Featured Plugins'),
            _isLoadingFeatured
                ? SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    ),
                  )
                : SizedBox(
                    height: 160,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _featuredPluginsList.map((entry) {
                        final name = entry['name']!;
                        final url = entry['url']!;
                        final isAlreadyInstalled = installedJs.any((p) => p.name.toLowerCase().contains(name.toLowerCase()));

                        return Container(
                          width: 210,
                          margin: const EdgeInsets.only(right: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  'Dynamic search and stream resolution for $name.',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: _isInstalling ? null : () => _installPlugin(url),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAlreadyInstalled 
                                          ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                                          : Theme.of(context).colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      isAlreadyInstalled ? 'Reinstall' : 'Install',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
                                        color: isAlreadyInstalled 
                                            ? (isDark ? Colors.white70 : Colors.black87)
                                            : Colors.white,),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

            const SizedBox(height: 20),

            // Built-in Sources
            AppleMusicSectionHeader(title: 'Built-in Sources'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: _BuiltInSourceTile(
                icon: Icons.play_circle,
                name: 'YouTube',
                description: 'YouTube audio streams via InnerTube',
                enabled: ref.watch(settingsProvider).enableYouTubeScraper,
                onToggle: (val) => ref.read(settingsProvider.notifier).setYouTubeScraperEnabled(val),
              ),
            ),

            const SizedBox(height: 20),

            // Installed Plugins List
            AppleMusicSectionHeader(
              title: 'Installed Addons',
              subtitle: '${allItems.length} source(s) active',
            ),
            if (allItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No external plugins installed yet.',
                    style: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                  ),
                ),
              )
            else
              GlassCard(
                padding: EdgeInsets.zero,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allItems.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = allItems.removeAt(oldIndex);
                    allItems.insert(newIndex, item);
                    
                    final newPriority = allItems.map<String>((x) {
                      return x is JsPlugin ? x.id : 'eclipse_${x.id}';
                    }).toList();
                    ref.read(settingsProvider.notifier).setAddonPriority(newPriority);
                  },
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isEclipse = item is !JsPlugin; // item is EclipseAddon
                    final id = isEclipse ? item.id : item.id;
                    final name = isEclipse ? item.name : item.name;
                    final icon = isEclipse ? item.icon : item.icon;
                    final version = isEclipse ? item.version : item.version;
                    final description = isEclipse ? item.description : item.description;
                    final enabled = isEclipse ? item.enabled : item.enabled;
                    final keyVal = isEclipse ? 'eclipse_$id' : id;

                    return Column(
                      key: ValueKey(keyVal),
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: icon != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      icon,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.extension,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : Icon(Icons.extension, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'v$version',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
                                    ),
                                  ),
                                ],
                              ),
                              if (isEclipse) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Eclipse API',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.cyanAccent,),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            description,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: enabled,
                                onChanged: (val) async {
                                  if (isEclipse) {
                                    await _pluginManager.toggleEclipseAddon(id, val);
                                  } else {
                                    await _pluginManager.togglePlugin(id, val);
                                  }
                                  _refreshPlugins();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () async {
                                  if (isEclipse) {
                                    await _pluginManager.deleteEclipseAddon(id);
                                  } else {
                                    await _pluginManager.deletePlugin(id);
                                  }
                                  _refreshPlugins();
                                },
                              ),
                              Icon(
                                Icons.drag_handle_rounded,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        if (item != allItems.last)
                          Divider(height: 1, indent: 72, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Search Test Console Section
            AppleMusicSectionHeader(title: 'Live Plugin Tester'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Query your installed plugins live to verify search and stream resolution output.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87,),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Target Plugin: ', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedTestPlugin,
                          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          hint: Text('Select a plugin', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                          items: [
                            ...installedJs.map((plugin) {
                              return DropdownMenuItem<String>(
                                value: plugin.id,
                                child: Text(plugin.name),
                              );
                            }),
                            ...installedEclipse.map((addon) {
                              return DropdownMenuItem<String>(
                                value: 'eclipse_${addon.id}',
                                child: Text('${addon.name} (Eclipse)'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedTestPlugin = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search keyword...',
                      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                        onPressed: _isTesting ? null : _testPluginSearch,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  
                  if (_isTesting) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    ),
                  ] else if (_testResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Search returned ${_testResults.length} result(s):',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold,),
                    ),
                    const SizedBox(height: 12),
                    ..._testResults.map((result) {
                      return Card(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(result.title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Artist: ${result.artist} · Formats: ${result.format}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.greenAccent),
                            onPressed: () async {
                              // Test playing
                              final dummyFile = TorBoxFile(
                                id: -result.url.hashCode.abs(),
                                torrentId: -1,
                                size: result.size,
                                name: result.title,
                                localPath: null,
                              );
                              
                              await audioHandler.customAction('play', {
                                'url': result.url,
                                'title': result.title,
                                'artist': result.artist,
                                'artworkUrl': result.thumbnail,
                                'forceReplace': true,
                                'extras': {
                                  'torrentId': dummyFile.torrentId,
                                  'fileId': dummyFile.id,
                                  'size': result.size,
                                  'localPath': null,
                                  'source': result.source,
                                  'linkType': result.linkType,
                                  'format': result.format,
                                },
                              });

                              if (!mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NowPlayingScreen(
                                    file: dummyFile,
                                    customQueue: [dummyFile],
                                    initialArtwork: result.thumbnail,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _BuiltInSourceTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _BuiltInSourceTile({
    required this.icon,
    required this.name,
    required this.description,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(
            name,
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            description,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Switch(
            value: enabled,
            onChanged: onToggle,
          ),
        ),
        Divider(height: 1, indent: 72, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ],
    );
  }
}
