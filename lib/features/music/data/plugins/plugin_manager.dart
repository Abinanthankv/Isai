import 'dart:convert';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'js_plugin.dart';
import 'eclipse_addon.dart';
import '../music_models.dart';
import '../../../../core/di/injection.dart';
import '../../../settings/data/torbox_settings_repository.dart';

@lazySingleton
class PluginManager {
  final Dio _dio;
  final List<JsPlugin> _plugins = [];
  final List<EclipseAddon> _eclipseAddons = [];
  final YoutubeExplode _yt = YoutubeExplode();

  PluginManager(this._dio);

  Dio get dio => _dio;

  List<JsPlugin> get plugins => List.unmodifiable(_plugins);
  
  List<JsPlugin> get activePlugins {
    final active = _plugins.where((p) => p.enabled).toList();
    try {
      final priority = getIt<TorBoxSettingsRepository>().addonPriority;
      if (priority.isEmpty) return active;
      active.sort((a, b) {
        int idxA = priority.indexOf(a.id);
        int idxB = priority.indexOf(b.id);
        if (idxA == -1) idxA = 999999;
        if (idxB == -1) idxB = 999999;
        return idxA.compareTo(idxB);
      });
    } catch (_) {}
    return active;
  }

  List<EclipseAddon> get eclipseAddons => List.unmodifiable(_eclipseAddons);
  
  List<EclipseAddon> get activeEclipseAddons {
    final active = _eclipseAddons.where((a) => a.enabled).toList();
    try {
      final priority = getIt<TorBoxSettingsRepository>().addonPriority;
      if (priority.isEmpty) return active;
      active.sort((a, b) {
        int idxA = priority.indexOf('eclipse_${a.id}');
        int idxB = priority.indexOf('eclipse_${b.id}');
        if (idxA == -1) idxA = 999999;
        if (idxB == -1) idxB = 999999;
        return idxA.compareTo(idxB);
      });
    } catch (_) {}
    return active;
  }

  List<dynamic> get prioritizedActiveAddons {
    final activeJs = activePlugins;
    final activeEclipse = activeEclipseAddons;
    final all = <dynamic>[...activeJs, ...activeEclipse];
    try {
      final priority = getIt<TorBoxSettingsRepository>().addonPriority;
      if (priority.isEmpty) return all;
      all.sort((a, b) {
        final idA = a is JsPlugin ? a.id : 'eclipse_${(a as EclipseAddon).id}';
        final idB = b is JsPlugin ? b.id : 'eclipse_${(b as EclipseAddon).id}';
        int idxA = priority.indexOf(idA);
        int idxB = priority.indexOf(idB);
        if (idxA == -1) idxA = 999999;
        if (idxB == -1) idxB = 999999;
        return idxA.compareTo(idxB);
      });
    } catch (_) {}
    return all;
  }

  /// Add a plugin to the in-memory list (useful for tests or custom scenarios)
  void registerPluginInMemory(JsPlugin plugin) {
    _plugins.removeWhere((p) => p.id == plugin.id);
    _plugins.add(plugin);
  }


  /// Map of curated default plugins that the user can import with one click (Deprecated, use fetchFeaturedPluginsFromRepo)
  Map<String, String> get featuredPlugins => {
        'JioSaavn':
            'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/jiosaavn.js',
        'SoundCloud':
            'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/soundcloud.js',
        'YouTube (Streams)':
            'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/youtube.js',
        'MassTamilan':
            'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/masstamilan.js',
      };

  Future<List<Map<String, String>>> fetchFeaturedPluginsFromRepo() async {
    try {
      final response = await _dio.get<String>(
        'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/refs/heads/main/index.json',
        options: Options(
          headers: {
            'Cache-Control': 'no-cache',
          },
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return [];

      final list = jsonDecode(data) as List<dynamic>;
      final List<Map<String, String>> results = [];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String? ?? '';
          final idSuffix = id.split('.').last;
          
          String displayName = idSuffix;
          if (idSuffix.isNotEmpty) {
            displayName = idSuffix[0].toUpperCase() + idSuffix.substring(1);
            if (displayName.toLowerCase() == 'jiosaavn') {
              displayName = 'JioSaavn';
            } else if (displayName.toLowerCase() == 'masstamilan') {
              displayName = 'MassTamilan';
            } else if (displayName.toLowerCase() == 'soundcloud') {
              displayName = 'SoundCloud';
            } else if (displayName.toLowerCase() == 'youtube') {
              displayName = 'YouTube';
            }
          }

          final jsUrl = 'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/$idSuffix.js';
          results.add({
            'name': displayName,
            'url': jsUrl,
          });
        }
      }
      return results;
    } catch (e) {
      print('[PluginManager] Failed to fetch featured plugins: $e');
      // Fallback to defaults
      return [
        {
          'name': 'JioSaavn',
          'url': 'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/jiosaavn.js',
        },
        {
          'name': 'MassTamilan',
          'url': 'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/masstamilan.js',
        },
        {
          'name': 'SoundCloud',
          'url': 'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/soundcloud.js',
        },
        {
          'name': 'YouTube (Streams)',
          'url': 'https://raw.githubusercontent.com/Abinanthankv/isai-plugins-repo/main/plugins/youtube.js',
        }
      ];
    }
  }

  Future<void> init() async {
    await loadPlugins();
    await loadEclipseAddons();
    // Local debug plugins are kept in project files but no longer auto-loaded/referred in Addon Manager
    // await _loadLocalDebugPlugins();
    print('[PluginManager] Initialized with ${_plugins.length} JS plugins and ${_eclipseAddons.length} Eclipse Addons');
  }

  Future<void> _loadLocalDebugPlugins() async {
    try {
      // Load and synchronize bundled plugin assets to documents directory
      // so the latest local plugin code is always loaded on app startup.
      final assetPaths = [
        'plugins/youtube.js',
        'plugins/jiosaavn.js',
        'plugins/soundcloud.js',
        'plugins/masstamilan.js',
      ];

      for (final assetPath in assetPaths) {
        try {
          print('[PluginManager] Synchronizing asset plugin: $assetPath');
          final code = await rootBundle.loadString(assetPath);
          if (code.trim().isEmpty) continue;

          final runtime = _createRuntime();
          try {
            runtime.evaluate(code);
            final manifestEval = runtime.evaluate('JSON.stringify(globalThis.manifest)');
            if (!manifestEval.isError && manifestEval.stringResult != 'null' && manifestEval.stringResult.isNotEmpty) {
              final manifest = jsonDecode(manifestEval.stringResult) as Map<String, dynamic>;
              final id = manifest['id'] as String?;
              final name = manifest['name'] as String?;
              if (id != null && name != null) {
                final existingPlugin = _plugins.where((p) => p.id == id).firstOrNull;
                final bool isEnabled = existingPlugin?.enabled ?? false; // default to disabled!

                final plugin = JsPlugin(
                  id: id,
                  name: name,
                  version: manifest['version'] as String? ?? '1.0.0',
                  description: manifest['description'] as String? ?? '',
                  icon: manifest['icon'] as String?,
                  code: code,
                  enabled: isEnabled,
                  sourceUrl: 'asset://$assetPath',
                );

                // Save to disk
                final dir = await _getPluginsDirectory();
                final outFile = io.File('${dir.path}/$id.json');
                await outFile.writeAsString(jsonEncode(plugin.toJson()), flush: true);

                // Update memory list
                if (existingPlugin != null) {
                  _plugins.remove(existingPlugin);
                }
                _plugins.add(plugin);
                print('[PluginManager] Synchronized asset plugin: $name ($id)');
              }
            }
          } catch (e) {
            print('[PluginManager] Failed to compile asset plugin at $assetPath: $e');
          } finally {
            runtime.dispose();
          }
        } catch (e) {
          print('[PluginManager] Asset $assetPath not found or failed to load: $e');
        }
      }
    } catch (e) {
      print('[PluginManager] Error loading local asset plugins: $e');
    }
  }

  /// Get the plugins subdirectory inside the app's document folder
  Future<io.Directory> _getPluginsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = io.Directory('${docs.path}/plugins');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<io.Directory> _getEclipseAddonsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = io.Directory('${docs.path}/eclipse_addons');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Load all saved plugins from the file system
  Future<void> loadPlugins() async {
    try {
      _plugins.clear();
      final dir = await _getPluginsDirectory();
      final files = dir.listSync();

      for (final file in files) {
        if (file is io.File && file.path.endsWith('.json')) {
          try {
            final content = file.readAsStringSync();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final plugin = JsPlugin.fromJson(json);
            _plugins.add(plugin);
          } catch (e) {
            print('[PluginManager] Error reading plugin file ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      print('[PluginManager] Error loading plugins: $e');
    }
  }

  Future<void> loadEclipseAddons() async {
    try {
      _eclipseAddons.clear();
      final dir = await _getEclipseAddonsDirectory();
      final files = dir.listSync();

      for (final file in files) {
        if (file is io.File && file.path.endsWith('.json')) {
          try {
            final content = file.readAsStringSync();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final addon = EclipseAddon.fromJson(json);
            _eclipseAddons.add(addon);
          } catch (e) {
            print('[PluginManager] Error reading eclipse addon file ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      print('[PluginManager] Error loading eclipse addons: $e');
    }
  }

  /// Helper to create and configure a JavascriptRuntime.
  ///
  /// Uses a custom Dio-based fetch via sendMessage bridge. When sendMessage
  /// handler returns a Dart Future, flutter_js's _dartToJs converts it to
  /// a JS Promise. The handlePromise extension polls executePendingJob()
  /// to resolve the promise chain.
  JavascriptRuntime _createRuntime() {
    // Create runtime WITHOUT XHR (we provide our own Dio-based fetch)
    final runtime = getJavascriptRuntime(xhr: false);

    // 1. Dio-based fetch bridge via sendMessage
    // The handler returns a Future<String> which flutter_js converts to
    // a JS Promise via _dartToJs. The handlePromise polling mechanism
    // calls executePendingJob() to resolve the promise.
    runtime.onMessage('fetchBridge', (args) {
      // args arrives pre-decoded from JSON by flutter_js's sendMessage internals
      final request = Map<String, dynamic>.from(args as Map);
      final url = request['url'] as String;
      final method = (request['method'] as String?) ?? 'GET';
      final rawHeaders = request['headers'];
      final headers = rawHeaders != null
          ? Map<String, dynamic>.from(rawHeaders as Map)
          : <String, dynamic>{};
      final body = request['body'] as String?;

      // Return a Future — flutter_js will convert it to a JS Promise
      return _dio.request<dynamic>(
        url,
        options: Options(
          method: method,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            ...headers,
          },
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: body,
      ).then((response) {
        return jsonEncode({
          'status': response.statusCode ?? 200,
          'body': response.data,
        });
      }).catchError((e) {
        print('[PluginRuntime Network Error] $e');
        String errMsg = e.toString();
        if (e is DioException) {
          errMsg = e.message ?? e.toString();
        }
        return jsonEncode({
          'status': 500,
          'body': errMsg,
        });
      });
    });

    // 2. Console bridge
    runtime.onMessage('pluginLog', (args) {
      print('[Plugin JS] $args');
      return '';
    });

    runtime.onMessage('pluginError', (args) {
      print('[Plugin JS ERROR] $args');
      return '';
    });

    // 4. Native YouTube Explode bridge for fast stream extraction
    runtime.onMessage('youtubeExplodeSearch', (args) {
      final query = args as String;
      return _yt.search.search(query).then((videos) {
        final results = videos.take(15).map((v) {
          final durationSecs = v.duration?.inSeconds ?? 0;
          final mins = durationSecs ~/ 60;
          final secs = durationSecs % 60;
          final duration = '$mins:${secs < 10 ? '0$secs' : secs}';
          
          return {
            'title': v.title,
            'artist': v.author,
            'url': v.id.value,
            'trackId': v.id.value,
            'isLazy': true,
            'size': 0,
            'format': 'YouTube (Audio)',
            'source': 'YouTube (Plugin)',
            'thumbnail': v.thumbnails.highResUrl,
            'duration': duration,
            'extras': {
              'videoId': v.id.value,
              'author': v.author,
              'durationSeconds': durationSecs,
            },
          };
        }).toList();
        return jsonEncode(results);
      }).catchError((e) {
        print('[PluginRuntime YouTube Search Error] $e');
        return '[]';
      });
    });

    runtime.onMessage('youtubeExplodeGetStream', (args) {
      final videoId = args as String;
      return _yt.videos.streamsClient.getManifest(
        videoId, 
        ytClients: [YoutubeApiClient.android, YoutubeApiClient.ios, YoutubeApiClient.tv],
      ).then((manifest) {
        final audioStreams = manifest.audioOnly.where((s) => s.container.toString().toLowerCase().contains('mp4'));
        final streamInfo = audioStreams.isNotEmpty 
            ? audioStreams.withHighestBitrate() 
            : manifest.audioOnly.withHighestBitrate();
        return streamInfo.url.toString();
      }).catchError((e) {
        print('[PluginRuntime YouTube Stream Error] $e');
        return '';
      });
    });

    // 3. Inject console + fetch polyfill + youtubeExplode bridge helper
    runtime.evaluate('''
      var console = {
        log: function() {
          try { sendMessage('pluginLog', JSON.stringify(Array.prototype.slice.call(arguments))); } catch(e) {}
        },
        error: function() {
          try { sendMessage('pluginError', JSON.stringify(Array.prototype.slice.call(arguments))); } catch(e) {}
        },
        warn: function() {
          try { sendMessage('pluginLog', JSON.stringify(Array.prototype.slice.call(arguments))); } catch(e) {}
        },
        info: function() {
          try { sendMessage('pluginLog', JSON.stringify(Array.prototype.slice.call(arguments))); } catch(e) {}
        }
      };

      globalThis.fetch = function(url, options) {
        options = options || {};
        var method = options.method || 'GET';
        var headers = options.headers || {};
        var body = typeof options.body === 'string' ? options.body : (options.body ? JSON.stringify(options.body) : '');

        var responsePromise = sendMessage('fetchBridge', JSON.stringify({
          url: url,
          method: method,
          headers: headers,
          body: body
        }));

        return responsePromise.then(function(responseStr) {
          var response = JSON.parse(responseStr);
          return {
            status: response.status,
            ok: response.status >= 200 && response.status < 300,
            text: function() { return Promise.resolve(typeof response.body === 'string' ? response.body : JSON.stringify(response.body)); },
            json: function() { return Promise.resolve(typeof response.body === 'string' ? JSON.parse(response.body) : response.body); }
          };
        });
      };

      globalThis.youtubeExplode = {
        search: function(query) {
          return sendMessage('youtubeExplodeSearch', query).then(function(resStr) {
            return JSON.parse(resStr);
          });
        },
        getStream: function(videoId) {
          return sendMessage('youtubeExplodeGetStream', videoId);
        }
      };
    ''');

    return runtime;
  }


  /// Installs/updates a JS plugin from a remote URL
  Future<JsPlugin> installPluginFromUrl(String url) async {
    print('[PluginManager] Downloading plugin from $url');
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Cache-Control': 'no-cache',
        },
      ),
    );

    final code = response.data;
    if (code == null || code.trim().isEmpty) {
      throw Exception('Downloaded code is empty or null');
    }

    // Validate the plugin by executing it in a sandbox runtime
    final runtime = _createRuntime();
    try {
      runtime.evaluate(code);

      // Check if globalThis.manifest is defined
      final manifestEval = runtime.evaluate('JSON.stringify(globalThis.manifest)');
      if (manifestEval.isError || manifestEval.stringResult == 'null' || manifestEval.stringResult.isEmpty) {
        throw Exception(
            'Plugin does not expose a global "manifest" object. Please verify the code structure.');
      }

      final manifest = jsonDecode(manifestEval.stringResult) as Map<String, dynamic>;
      final id = manifest['id'] as String?;
      final name = manifest['name'] as String?;
      final version = manifest['version'] as String?;
      final description = manifest['description'] as String?;
      final icon = manifest['icon'] as String?;

      if (id == null || id.isEmpty || name == null || name.isEmpty) {
        throw Exception('Plugin manifest is missing required fields (id or name)');
      }

      final plugin = JsPlugin(
        id: id,
        name: name,
        version: version ?? '1.0.0',
        description: description ?? '',
        icon: icon,
        code: code,
        enabled: true,
        sourceUrl: url,
      );

      // Save to disk
      final dir = await _getPluginsDirectory();
      final file = io.File('${dir.path}/$id.json');
      await file.writeAsString(jsonEncode(plugin.toJson()), flush: true);

      // Update in-memory list
      _plugins.removeWhere((p) => p.id == id);
      _plugins.add(plugin);

      print('[PluginManager] Successfully installed plugin: $name ($id)');
      return plugin;
    } finally {
      runtime.dispose();
    }
  }

  /// Toggles the enabled state of a plugin
  Future<void> togglePlugin(String id, bool enabled) async {
    final idx = _plugins.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final updated = _plugins[idx].copyWith(enabled: enabled);
      _plugins[idx] = updated;

      // Save updated to disk
      final dir = await _getPluginsDirectory();
      final file = io.File('${dir.path}/$id.json');
      if (file.existsSync()) {
        await file.writeAsString(jsonEncode(updated.toJson()), flush: true);
      }
      print('[PluginManager] Toggled plugin $id to $enabled');
    }
  }

  /// Uninstalls a plugin from the device
  Future<void> deletePlugin(String id) async {
    _plugins.removeWhere((p) => p.id == id);
    final dir = await _getPluginsDirectory();
    final jsonFile = io.File('${dir.path}/$id.json');
    if (jsonFile.existsSync()) {
      jsonFile.deleteSync();
    }
    print('[PluginManager] Uninstalled plugin $id');
  }

  /// Dynamic search against a specific plugin runtime.
  ///
  /// Uses evaluate() (synchronous JS eval that returns a Promise-as-Future)
  /// + handlePromise() (polls executePendingJob until the promise resolves)
  /// which is the correct pattern for flutter_js async operations.
  Future<List<ScraperResult>> search(String pluginId, String query) async {
    final plugin = _plugins.firstWhere((p) => p.id == pluginId);
    if (!plugin.enabled) return [];

    final runtime = _createRuntime();
    try {
      // Load plugin code
      final loadResult = runtime.evaluate(plugin.code);
      if (loadResult.isError) {
        print('[PluginManager] Error loading plugin code for $pluginId: ${loadResult.stringResult}');
        return [];
      }

      // Call search — evaluate returns synchronously with a JsEvalResult
      // whose rawResult is a Dart Future (from the JS Promise).
      final queryEscaped = jsonEncode(query);
      final invocation = 'globalThis.search($queryEscaped).then(function(res) { return JSON.stringify(res); })';
      final evalResult = runtime.evaluate(invocation);

      if (evalResult.isError) {
        print('[PluginManager] Search eval error in $pluginId: ${evalResult.stringResult}');
        return [];
      }

      // handlePromise will poll executePendingJob() until the promise resolves.
      // The XHR timer (40ms) handles the actual HTTP and calls back into JS,
      // and executePendingJob (20ms) flushes the microtask queue.
      final resolvedResult = await runtime.handlePromise(
        evalResult,
        timeout: const Duration(seconds: 30),
      );

      if (resolvedResult.isError) {
        print('[PluginManager] Search promise error in $pluginId: ${resolvedResult.stringResult}');
        return [];
      }

      final jsonResult = resolvedResult.stringResult;
      print('[PluginManager] Raw result from $pluginId: ${jsonResult.substring(0, jsonResult.length > 200 ? 200 : jsonResult.length)}...');

      if (jsonResult.isEmpty || jsonResult == 'null' || jsonResult == 'undefined') {
        return [];
      }

      final list = jsonDecode(jsonResult) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        
        // Ensure url incorporates lazy loading protocol if direct resolving isn't immediate
        final String rawUrl = map['url'] as String;
        final String trackId = map['trackId'] as String? ?? rawUrl;
        final bool isLazy = map['isLazy'] as bool? ?? true;
        
        final String resolvedUrl = isLazy 
            ? 'https://lazy.plugin.internal/$pluginId/${Uri.encodeComponent(trackId)}' 
            : rawUrl;

        return ScraperResult(
          title: map['title'] as String? ?? 'Unknown Title',
          artist: map['artist'] as String? ?? 'Unknown Artist',
          url: resolvedUrl,
          source: map['source'] as String? ?? plugin.name,
          size: (map['size'] as num?)?.toInt() ?? 0,
          format: map['format'] as String? ?? '320kbps MP3',
          linkType: pluginId,
          duration: map['duration']?.toString(),
          thumbnail: map['thumbnail'] as String?,
          extras: {
            if (map['extras'] != null) ...(map['extras'] as Map<String, dynamic>),
            'trackId': trackId,
            'pluginId': pluginId,
          },
        );
      }).toList();
    } catch (e, st) {
      print('[PluginManager] Exception running search for $pluginId: $e\n$st');
      return [];
    } finally {
      runtime.dispose();
    }
  }

  /// Dynamic streaming URL resolution
  Future<String?> resolveStream(String pluginId, String trackId) async {
    final plugin = _plugins.firstWhere((p) => p.id == pluginId);
    final runtime = _createRuntime();

    try {
      runtime.evaluate(plugin.code);

      // Call getStream function — same evaluate + handlePromise pattern
      final trackIdEscaped = jsonEncode(trackId);
      final invocation = 'globalThis.getStream($trackIdEscaped)';
      final evalResult = runtime.evaluate(invocation);

      if (evalResult.isError) {
        print('[PluginManager] Stream resolution eval error in $pluginId: ${evalResult.stringResult}');
        return null;
      }

      final resolvedResult = await runtime.handlePromise(
        evalResult,
        timeout: const Duration(seconds: 30),
      );

      if (resolvedResult.isError) {
        print('[PluginManager] Stream resolution promise error in $pluginId: ${resolvedResult.stringResult}');
        return null;
      }

      final streamUrl = resolvedResult.stringResult;
      if (streamUrl.isEmpty || streamUrl == 'null' || streamUrl == 'undefined') {
        return null;
      }

      // If QuickJS returns a JSON string instead of raw string
      if (streamUrl.startsWith('"') && streamUrl.endsWith('"')) {
        return jsonDecode(streamUrl) as String;
      }
      return streamUrl;
    } catch (e, st) {
      print('[PluginManager] Exception running getStream for $pluginId: $e\n$st');
      return null;
    } finally {
      runtime.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Eclipse Addons Implementation
  // ---------------------------------------------------------------------------

  Future<EclipseAddon> installEclipseAddon(String baseUrl) async {
    print('[PluginManager] Installing Eclipse Addon from $baseUrl');
    
    String url = baseUrl;
    String manifestUrl;
    if (url.endsWith('/manifest.json')) {
      manifestUrl = url;
      url = url.substring(0, url.length - '/manifest.json'.length);
    } else {
      url = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      manifestUrl = '$url/manifest.json';
    }

    final response = await _dio.get<String>(
      manifestUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Cache-Control': 'no-cache'},
      ),
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Manifest is empty');
    }

    final manifest = jsonDecode(data) as Map<String, dynamic>;
    final id = manifest['id'] as String?;
    final name = manifest['name'] as String?;
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw Exception('Eclipse Addon manifest missing id or name');
    }

    final addon = EclipseAddon(
      id: id,
      name: name,
      version: manifest['version'] as String? ?? '1.0.0',
      description: manifest['description'] as String? ?? '',
      icon: manifest['icon'] as String?,
      baseUrl: url,
      enabled: true,
    );

    // Save to disk
    final dir = await _getEclipseAddonsDirectory();
    final file = io.File('${dir.path}/$id.json');
    await file.writeAsString(jsonEncode(addon.toJson()), flush: true);

    _eclipseAddons.removeWhere((a) => a.id == id);
    _eclipseAddons.add(addon);

    print('[PluginManager] Successfully installed Eclipse Addon: $name ($id)');
    return addon;
  }

  Future<void> toggleEclipseAddon(String id, bool enabled) async {
    final idx = _eclipseAddons.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final updated = _eclipseAddons[idx].copyWith(enabled: enabled);
      _eclipseAddons[idx] = updated;

      final dir = await _getEclipseAddonsDirectory();
      final file = io.File('${dir.path}/$id.json');
      if (file.existsSync()) {
        await file.writeAsString(jsonEncode(updated.toJson()), flush: true);
      }
    }
  }

  Future<void> deleteEclipseAddon(String id) async {
    _eclipseAddons.removeWhere((a) => a.id == id);
    final dir = await _getEclipseAddonsDirectory();
    final jsonFile = io.File('${dir.path}/$id.json');
    if (jsonFile.existsSync()) {
      jsonFile.deleteSync();
    }
  }

  Future<List<ScraperResult>> searchEclipse(String addonId, String query) async {
    final addon = _eclipseAddons.firstWhere((a) => a.id == addonId);
    if (!addon.enabled) return [];

    try {
      final searchUrl = '${addon.baseUrl}/search?q=${Uri.encodeComponent(query)}';
      final response = await _dio.get<String>(searchUrl);
      final data = response.data;
      if (data == null) return [];

      final json = jsonDecode(data) as Map<String, dynamic>;
      final tracks = json['tracks'] as List<dynamic>? ?? [];

      return tracks.map((trackObj) {
        final track = trackObj as Map<String, dynamic>;
        
        final String rawUrl = track['streamURL'] as String? ?? '';
        final String trackId = track['id'] as String? ?? rawUrl;
        
        // If the addon returns a streamURL, it's not lazy. Otherwise it's lazy.
        final bool isLazy = rawUrl.isEmpty;
        
        final String resolvedUrl = isLazy 
            ? 'https://lazy.plugin.internal/eclipse_$addonId/${Uri.encodeComponent(trackId)}' 
            : rawUrl;

        return ScraperResult(
          title: track['title'] as String? ?? 'Unknown Title',
          artist: track['artist'] as String? ?? 'Unknown Artist',
          url: resolvedUrl,
          source: addon.name,
          size: 0, // Eclipse addon tracks don't specify size
          format: track['format'] as String? ?? '320kbps MP3',
          linkType: 'eclipse_$addonId',
          duration: track['duration']?.toString(),
          thumbnail: track['artworkURL'] as String?,
          extras: {
            'trackId': trackId,
            'pluginId': addonId,
            'isEclipseAddon': true,
          },
        );
      }).toList();
    } catch (e) {
      print('[PluginManager] Exception running Eclipse Addon search for $addonId: $e');
      return [];
    }
  }

  Future<String?> resolveEclipseStream(String addonId, String trackId) async {
    final addon = _eclipseAddons.firstWhere((a) => a.id == addonId);
    try {
      final streamUrl = '${addon.baseUrl}/stream/${Uri.encodeComponent(trackId)}';
      final response = await _dio.get<String>(streamUrl);
      final data = response.data;
      if (data == null) return null;

      final json = jsonDecode(data) as Map<String, dynamic>;
      return json['url'] as String?;
    } catch (e) {
      print('[PluginManager] Exception running Eclipse stream resolution for $addonId: $e');
      return null;
    }
  }
}

