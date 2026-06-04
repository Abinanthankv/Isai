import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/apple_music_theme.dart';

class AppUpdater {
  static const String localVersion = '0.9.0';
  static const String _methodChannelName = 'com.isai.music/updater';
  static const String _ignoredVersionKey = 'ignored_app_version';

  static const MethodChannel _channel = MethodChannel(_methodChannelName);

  /// Performs version comparison
  static bool _isUpdateAvailable(String local, String latest) {
    try {
      final localParts = local.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      final latestParts = latest.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
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

  /// Checks for updates on GitHub.
  /// If [silent] is true, it won't show anything unless there is an update (used on startup).
  /// If [silent] is false, it shows a loading spinner and alerts "Up to date" if no update is found.
  static Future<void> checkForUpdate(BuildContext context, {required bool silent}) async {
    // Only support Android for in-app updates
    if (!Platform.isAndroid) return;

    OverlayEntry? loadingOverlay;
    if (!silent) {
      loadingOverlay = OverlayEntry(
        builder: (context) => Container(
          color: Colors.black45,
          child: const Center(
            child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
          ),
        ),
      );
      Overlay.of(context).insert(loadingOverlay);
    }

    try {
      final response = await Dio().get('https://api.github.com/repos/Abinanthankv/Isai/releases/latest');
      loadingOverlay?.remove();

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final tag = data['tag_name']?.toString() ?? '';
        final cleanLatestVersion = tag.replaceAll('v', '');
        final releaseNotes = data['body']?.toString() ?? 'No release notes available.';

        // Check if update is available
        final updateAvailable = _isUpdateAvailable(localVersion, cleanLatestVersion);

        if (updateAvailable) {
          // Check if this version is ignored (only for silent checks)
          if (silent) {
            final prefs = await SharedPreferences.getInstance();
            final ignored = prefs.getString(_ignoredVersionKey);
            if (ignored == cleanLatestVersion) {
              return;
            }
          }

          // Retrieve device ABI
          String deviceAbi = '';
          try {
            deviceAbi = await _channel.invokeMethod<String>('getDeviceAbi') ?? '';
          } catch (e) {
            print('[AppUpdater] Failed to get device ABI: $e');
          }

          // Extract APK URL and details
          String? downloadUrl;
          String apkName = 'isai-release.apk';
          double fileSizeMb = 0.0;
          
          final assets = data['assets'] as List<dynamic>? ?? [];
          Map<String, dynamic>? targetAsset;

          // 1. Look for a split APK matching the device architecture first (saves bandwidth)
          if (deviceAbi.isNotEmpty) {
            final abiLower = deviceAbi.toLowerCase();
            String? preferredSig;
            if (abiLower.contains('arm64') || abiLower.contains('v8a')) {
              preferredSig = 'v8a'; // our build script maps arm64-v8a to v8a
            } else if (abiLower.contains('v7a') || abiLower.contains('armeabi')) {
              preferredSig = 'v7a'; // our build script maps armeabi-v7a to v7a
            } else if (abiLower.contains('x86_64')) {
              preferredSig = 'x86_64';
            } else if (abiLower.contains('x86')) {
              preferredSig = 'x86';
            }

            if (preferredSig != null) {
              for (final asset in assets) {
                final name = asset['name']?.toString()?.toLowerCase() ?? '';
                if (name.endsWith('.apk') && name.contains(preferredSig)) {
                  targetAsset = asset;
                  break;
                }
              }
            }
          }

          // 2. If no matching split APK is found, try to locate the universal/standard APK
          if (targetAsset == null) {
            final abiSignatures = ['v8a', 'v7a', 'arm64', 'arm', 'x86_64', 'x86'];
            for (final asset in assets) {
              final name = asset['name']?.toString()?.toLowerCase() ?? '';
              if (name.endsWith('.apk')) {
                final containsAbi = abiSignatures.any((sig) => name.contains(sig));
                if (!containsAbi) {
                  targetAsset = asset;
                  break;
                }
              }
            }
          }

          // 3. Fallback to any APK if still not found
          if (targetAsset == null && assets.isNotEmpty) {
            for (final asset in assets) {
              final name = asset['name']?.toString() ?? '';
              if (name.endsWith('.apk')) {
                targetAsset = asset;
                break;
              }
            }
          }

          if (targetAsset != null) {
            downloadUrl = targetAsset['browser_download_url']?.toString();
            apkName = targetAsset['name']?.toString() ?? apkName;
            final bytes = (targetAsset['size'] as num?)?.toDouble() ?? 0.0;
            fileSizeMb = bytes / (1024 * 1024);
          }

          if (downloadUrl != null && context.mounted) {
            _showUpdateModal(
              context,
              versionName: tag,
              apkName: apkName,
              fileSizeMb: fileSizeMb,
              releaseNotes: releaseNotes,
              downloadUrl: downloadUrl,
              cleanLatestVersion: cleanLatestVersion,
            );
          }
        } else if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are on the latest version!')),
          );
        }
      }
    } on DioException catch (e) {
      loadingOverlay?.remove();
      print('[AppUpdater] Update check failed: $e');
      if (!silent && context.mounted) {
        if (e.response?.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are on the latest version! (No releases found)')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to check for updates')),
          );
        }
      }
    } catch (e) {
      loadingOverlay?.remove();
      print('[AppUpdater] Update check failed: $e');
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check for updates')),
        );
      }
    }
  }

  static void _showUpdateModal(
    BuildContext context, {
    required String versionName,
    required String apkName,
    required double fileSizeMb,
    required String releaseNotes,
    required String downloadUrl,
    required String cleanLatestVersion,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UpdateDialogContent(
          versionName: versionName,
          apkName: apkName,
          fileSizeMb: fileSizeMb,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          cleanLatestVersion: cleanLatestVersion,
        );
      },
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final String versionName;
  final String apkName;
  final double fileSizeMb;
  final String releaseNotes;
  final String downloadUrl;
  final String cleanLatestVersion;

  const _UpdateDialogContent({
    required this.versionName,
    required this.apkName,
    required this.fileSizeMb,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.cleanLatestVersion,
  });

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = 'A new version is ready to install.';
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...';
      _downloadProgress = 0.0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/${widget.apkName}';
      
      _cancelToken = CancelToken();
      await Dio().download(
        widget.downloadUrl,
        apkPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      // Trigger installation
      setState(() {
        _statusText = 'Installing update...';
      });
      
      final success = await AppUpdater._channel.invokeMethod('installApk', {'path': apkPath});
      if (success == true) {
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Native installation returned false');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusText = 'A new version is ready to install.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download or install update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2736), // Deep blue-gray matching the design screenshot
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title (e.g., 0.2.3-hotfix)
            Text(
              widget.versionName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle status (e.g. A new version is ready to install / Downloading update...)
            Text(
              _statusText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Inner Card containing: Version, Size, Filename
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2), // Translucent inner card
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cleanLatestVersion,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.fileSizeMb.toStringAsFixed(1)} MB · ${widget.apkName}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)), // Light blue progress bar
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Downloading % text
                    Text(
                      'Downloading ${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Release Notes Section
            const Text(
              'Release notes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Release Notes box
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.releaseNotes,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isDownloading ? null : _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3), // Bright Blue matching design screenshot
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isDownloading ? 'Downloading update...' : 'Update',
                  style: TextStyle(
                    color: _isDownloading ? Colors.white.withOpacity(0.2) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDownloading
                        ? null
                        : () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(AppUpdater._ignoredVersionKey, widget.cleanLatestVersion);
                            if (mounted) Navigator.pop(context);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.6),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ignore', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDownloading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.6),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Later', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
