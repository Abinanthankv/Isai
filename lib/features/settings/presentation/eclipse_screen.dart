import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../music/presentation/music_providers.dart';
import '../../music/presentation/playlist_providers.dart';

class EclipseAccountScreen extends ConsumerStatefulWidget {
  const EclipseAccountScreen({super.key});

  @override
  ConsumerState<EclipseAccountScreen> createState() => _EclipseAccountScreenState();
}

class _EclipseAccountScreenState extends ConsumerState<EclipseAccountScreen> {
  bool _isSyncing = false;
  int? _syncedCount;

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncedCount = null;
    });
    try {
      final notifier = ref.read(playlistProvider.notifier);
      await notifier.importEclipsePlaylists();
      final count = await notifier.syncLocalPlaylistsToEclipse();
      if (mounted) {
        setState(() {
          _syncedCount = count;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Eclipse Account',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: settings.eclipseAvatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              settings.eclipseAvatarUrl!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.cloud, size: 40, color: theme.colorScheme.primary),
                            ),
                          )
                        : Icon(Icons.cloud, size: 40, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    settings.eclipseUsername ?? 'Eclipse User',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (settings.eclipseEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      settings.eclipseEmail!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Username', value: settings.eclipseUsername ?? '—', isDark: isDark),
                  const Divider(height: 24),
                  _DetailRow(label: 'Email', value: settings.eclipseEmail ?? '—', isDark: isDark),
                  const Divider(height: 24),
                  _DetailRow(label: 'User ID', value: settings.eclipseUserId ?? '—', isDark: isDark),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Scrobble Playback', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Record plays to Eclipse after 50%', style: TextStyle(fontSize: 12)),
                value: settings.eclipseScrobbleEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setEclipseScrobbleEnabled(v),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isSyncing ? null : _syncNow,
                icon: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.sync, color: theme.colorScheme.primary),
                label: Text(
                  _isSyncing
                      ? 'Syncing…'
                      : _syncedCount != null
                          ? 'Synced $_syncedCount playlist${_syncedCount == 1 ? '' : 's'}'
                          : 'Sync Now',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(settingsProvider.notifier).eclipseLogout();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
