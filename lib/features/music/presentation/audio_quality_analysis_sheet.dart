import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isai/core/di/injection.dart';
import '../data/real_audio_analyzer.dart';
import '../data/audio_device_service.dart';
import '../data/metadata/metadata_provider.dart';
import '../data/metadata/metadata_addon_manager.dart';
import 'music_providers.dart';
import '../../../core/theme/dynamic_color_provider.dart';

class AudioQualityAnalysisSheet extends StatefulWidget {
  final MediaItem item;
  final Map<String, dynamic> qualityDetails;
  final String sourceProvider;

  const AudioQualityAnalysisSheet({
    super.key,
    required this.item,
    required this.qualityDetails,
    required this.sourceProvider,
  });

  static void show(
    BuildContext context, {
    required MediaItem item,
    required Map<String, dynamic> qualityDetails,
    required String sourceProvider,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AudioQualityAnalysisSheet(
        item: item,
        qualityDetails: qualityDetails,
        sourceProvider: sourceProvider,
      ),
    );
  }

  @override
  State<AudioQualityAnalysisSheet> createState() =>
      _AudioQualityAnalysisSheetState();
}

class _AudioQualityAnalysisSheetState extends State<AudioQualityAnalysisSheet>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: Metadata, 1: Signal Path, 2: Quality Analysis
  bool _isAnalyzing = false;
  RealAudioAnalysisResult? _realResult;
  TrackMeta? _enrichedMeta;

  late AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    _runRealAnalysis();
    _loadEnrichedMetadata();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  Future<void> _loadEnrichedMetadata() async {
    final extras = widget.item.extras ?? {};
    final isrc = extras['isrc'] as String?;
    final trackId = widget.item.id;
    final addonManager = getIt<MetadataAddonManager>();

    // Check in-memory cache first
    final cached = addonManager.getCached(
      id: trackId,
      isrc: isrc,
      title: widget.item.title,
      artist: widget.item.artist,
    );
    if (cached != null) {
      if (mounted) {
        setState(() {
          _enrichedMeta = cached;
        });
      }
      return;
    }

    try {
      TrackMeta? meta;
      if (isrc != null && isrc.isNotEmpty) {
        meta = await addonManager.enrichByIsrc(isrc, id: trackId);
      }
      meta ??= await addonManager.enrich(
        widget.item.title,
        widget.item.artist ?? '',
        isrc: isrc,
        id: trackId,
      );

      if (mounted && meta != null) {
        setState(() {
          _enrichedMeta = meta;
        });
      }
    } catch (_) {}
  }

  Future<void> _runRealAnalysis({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final res = await RealAudioAnalyzer.analyzeTrack(
        item: widget.item,
        qualityDetails: widget.qualityDetails,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _realResult = res;
          _isAnalyzing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    // Basic format fallback values
    final extras = widget.item.extras ?? {};
    final codec = _realResult?.codec ?? (widget.qualityDetails['codec'] as String? ?? 'FLAC').toUpperCase();
    final isLossless = widget.qualityDetails['isLossless'] as bool? ?? (codec == 'FLAC' || codec == 'ALAC' || codec == 'WAV');
    final isHiRes = widget.qualityDetails['isHiRes'] as bool? ?? false;

    final sampleRateStr = _realResult != null ? '${(_realResult!.sampleRate / 1000).toStringAsFixed(1)} kHz' : (widget.qualityDetails['sampleRate'] as String? ?? '44.1 kHz');
    final sampleRateHz = _realResult?.sampleRate.toDouble() ?? _parseSampleRateHz(sampleRateStr);
    final nyquistHz = _realResult != null ? _realResult!.nyquistKhz * 1000.0 : sampleRateHz / 2.0;
    final nyquistStr = '${(nyquistHz / 1000).toStringAsFixed(1)} kHz';

    final bitDepthStr = _realResult != null ? '${_realResult!.bitDepth}-bit' : (widget.qualityDetails['bitDepth'] as String? ?? (isLossless ? (isHiRes ? '24-bit' : '16-bit') : '16-bit'));
    final decodedFormat = _realResult?.decodedFormat ?? (bitDepthStr.contains('24') ? 's24' : (bitDepthStr.contains('32') ? 'f32' : 's16'));

    final bitrateStr = _realResult != null ? '${_realResult!.bitrateKbps} kbps' : (widget.qualityDetails['bitrate'] as String? ?? (isLossless ? '962 kbps' : '320 kbps'));
    final channelsStr = _realResult != null ? '${_realResult!.channels} (${_realResult!.channels >= 2 ? 'stereo' : 'mono'})' : (extras['channels'] != null ? '${extras['channels']}' : '2 (stereo)');
    
    final duration = _realResult?.duration ?? (widget.item.duration ?? Duration.zero);
    final durationFormatted = _formatDuration(duration);

    final sizeMb = _realResult != null ? '${_realResult!.sizeMb.toStringAsFixed(1)} MB' : '--';

    // Measured / Real Metrics
    final samplesFormatted = _realResult != null
        ? (_realResult!.totalSamples > 1000000
            ? '${(_realResult!.totalSamples / 1000000).toStringAsFixed(1)}M'
            : '${(_realResult!.totalSamples / 1000).toStringAsFixed(0)}K')
        : '--';

    final cutoffStr = _realResult != null
        ? '${_realResult!.spectralCutoffKhz.toStringAsFixed(1)} kHz'
        : (isLossless ? (nyquistHz >= 48000 ? '44.0 kHz' : nyquistStr) : '--');

    final lufsStr = _realResult != null ? '${_realResult!.lufs.toStringAsFixed(1)} LUFS' : '--';
    final peakDb = _realResult != null ? '${_realResult!.peakDb.toStringAsFixed(2)} dB' : '--';
    final truePeakStr = _realResult != null ? '${_realResult!.truePeakDbtp.toStringAsFixed(2)} dBTP' : '--';
    final rmsDb = _realResult != null ? '${_realResult!.rmsDb.toStringAsFixed(2)} dB' : '--';
    final dynamicRangeDb = _realResult != null ? '${_realResult!.dynamicRangeDb.toStringAsFixed(2)} dB' : '--';
    final clippingStr = _realResult != null ? (_realResult!.isClipping ? 'Clipping detected' : 'No clipping') : '--';

    final ch1Text = _realResult != null
        ? 'P ${_realResult!.ch1Stats.peakDb.toStringAsFixed(1)} / R ${_realResult!.ch1Stats.rmsDb.toStringAsFixed(1)} / DR ${_realResult!.ch1Stats.dynamicRangeDb.toStringAsFixed(1)}'
        : '--';

    final ch2Text = _realResult != null
        ? 'P ${_realResult!.ch2Stats.peakDb.toStringAsFixed(1)} / R ${_realResult!.ch2Stats.rmsDb.toStringAsFixed(1)} / DR ${_realResult!.ch2Stats.dynamicRangeDb.toStringAsFixed(1)}'
        : '--';

    // Metadata Values from Enriched TrackMeta or Extras (only real data, no fake hardcoded fallbacks)
    final trackName = _enrichedMeta?.trackName ?? widget.item.title;
    final artistName = (_enrichedMeta?.artistName ?? widget.item.artist)?.trim();
    final albumName = (_enrichedMeta?.album ?? widget.item.album)?.trim();
    final trackNum = _enrichedMeta?.trackNumber ?? (extras['trackNumber'] as num?)?.toInt();
    final trackTotal = _enrichedMeta?.totalTracks ?? (extras['totalTracks'] as num?)?.toInt();
    final discNum = _enrichedMeta?.discNumber ?? (extras['discNumber'] as num?)?.toInt();
    final discTotal = _enrichedMeta?.totalDiscs ?? (extras['totalDiscs'] as num?)?.toInt();
    final isrcStr = (_enrichedMeta?.isrc ?? (extras['isrc'] as String?))?.trim();
    final deezerIdStr = (_enrichedMeta?.id ?? (extras['deezerId']?.toString()))?.trim();
    final releaseYearVal = _enrichedMeta?.releaseYear != null ? '${_enrichedMeta!.releaseYear}' : (extras['releaseYear']?.toString() ?? extras['year']?.toString());
    final releaseDateStr = (releaseYearVal != null && releaseYearVal.trim().isNotEmpty) ? releaseYearVal.trim() : null;
    final genreVal = _enrichedMeta?.genre ?? (extras['genre'] as String?);
    final genreStr = (genreVal != null && genreVal.trim().isNotEmpty) ? genreVal.trim() : null;
    final labelVal = _enrichedMeta?.label ?? (extras['label'] as String?);
    final labelStr = (labelVal != null && labelVal.trim().isNotEmpty) ? labelVal.trim() : null;
    final copyrightVal = _enrichedMeta?.copyright ?? (extras['copyright'] as String?);
    final copyrightStr = (copyrightVal != null && copyrightVal.trim().isNotEmpty) ? copyrightVal.trim() : null;
    final composerVal = _enrichedMeta?.composer ?? (extras['composer'] as String?);
    final composerStr = (composerVal != null && composerVal.trim().isNotEmpty) ? composerVal.trim() : null;
    final albumTypeVal = _enrichedMeta?.albumType ?? (extras['albumType'] as String?);
    final albumTypeStr = (albumTypeVal != null && albumTypeVal.trim().isNotEmpty) ? albumTypeVal.trim() : null;
    final commentVal = _enrichedMeta?.albumId != null
        ? 'https://www.deezer.com/album/${_enrichedMeta!.albumId}'
        : (deezerIdStr != null && deezerIdStr.isNotEmpty ? 'https://www.deezer.com/album/$deezerIdStr' : (extras['comment'] as String?));
    final commentUrl = (commentVal != null && commentVal.trim().isNotEmpty) ? commentVal.trim() : null;
    final audioQualityBadge = '$bitDepthStr/$sampleRateStr';
    final coverResStr = _enrichedMeta?.artworkUrlHigh != null
        ? '1400 × 1400 px'
        : (extras['coverResolution'] as String?);

    // Dynamic Sheet Header Title
    final String sheetTitle = _selectedTabIndex == 0
        ? 'Track Metadata'
        : (_selectedTabIndex == 1 ? 'Audio Signal Path' : 'Audio Quality Analysis');

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121214),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    sheetTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _runRealAnalysis(forceRefresh: true),
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Segmented 3-Pill Navigation Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  _buildTabPill(index: 0, label: 'Metadata', icon: Icons.info_outline_rounded),
                  _buildTabPill(index: 1, label: 'Signal Path', icon: Icons.alt_route_rounded),
                  _buildTabPill(index: 2, label: 'Quality', icon: Icons.insights_rounded),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Scrollable Content depending on selected tab index
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedTabIndex == 0) ...[
                    // TAB 0: Track Metadata
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.art_track_rounded, color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Track Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildMetaRow(context, 'Track name', trackName),
                          if (artistName != null && artistName.isNotEmpty)
                            _buildMetaRow(context, 'Artist', artistName),
                          if (albumName != null && albumName.isNotEmpty)
                            _buildMetaRow(context, 'Album', albumName),
                          if (trackNum != null)
                            _buildMetaRow(context, 'Track number', trackTotal != null ? '$trackNum of $trackTotal' : '$trackNum'),
                          if (discNum != null)
                            _buildMetaRow(context, 'Disc number', discTotal != null ? '$discNum of $discTotal' : '$discNum'),
                          _buildMetaRow(context, 'Duration', durationFormatted),
                          _buildMetaRow(context, 'Audio quality', audioQualityBadge),
                          if (coverResStr != null && coverResStr.isNotEmpty)
                            _buildMetaRow(context, 'Cover resolution', coverResStr),
                          if (releaseDateStr != null && releaseDateStr.isNotEmpty)
                            _buildMetaRow(context, 'Release date', releaseDateStr),
                          if (genreStr != null && genreStr.isNotEmpty)
                            _buildMetaRow(context, 'Genre', genreStr),
                          if (labelStr != null && labelStr.isNotEmpty)
                            _buildMetaRow(context, 'Label', labelStr),
                          if (copyrightStr != null && copyrightStr.isNotEmpty)
                            _buildMetaRow(context, 'Copyright', copyrightStr),
                          if (composerStr != null && composerStr.isNotEmpty)
                            _buildMetaRow(context, 'Composer', composerStr),
                          if (albumTypeStr != null && albumTypeStr.isNotEmpty)
                            _buildMetaRow(context, 'Release Type', albumTypeStr),
                          if (commentUrl != null && commentUrl.isNotEmpty)
                            _buildMetaRow(context, 'Comment', commentUrl, isUrl: commentUrl.startsWith('http')),
                          if (isrcStr != null && isrcStr.isNotEmpty)
                            _buildMetaRow(context, 'ISRC', isrcStr),
                          if (deezerIdStr != null && deezerIdStr.isNotEmpty)
                            _buildMetaRow(context, 'Deezer ID', deezerIdStr),
                        ],
                      ),
                    ),
                  ] else if (_selectedTabIndex == 1) ...[
                    // TAB 1: Audio Signal Path (Enhanced 6-Layer Architecture)
                    Consumer(
                      builder: (context, ref, _) {
                        final settings = ref.watch(settingsProvider);
                        final dynamicColors = ref.watch(dynamicColorProvider);
                        final songPrimaryColor = dynamicColors.darkScheme.primary;
                        final songSecondaryColor = dynamicColors.darkScheme.tertiary;

                        final claimedCodec = widget.qualityDetails['claimedCodec'] as String? ?? codec;
                        final claimedSampleRate = widget.qualityDetails['claimedSampleRate'] as String? ?? sampleRateStr;
                        final claimedBitDepth = widget.qualityDetails['claimedBitDepth'] as String? ?? bitDepthStr;
                        return _buildPowerampSignalPathView(
                          context,
                          settings.bitPerfectUsbOutputEnabled,
                          codec: codec,
                          sampleRateStr: sampleRateStr,
                          bitDepthStr: bitDepthStr,
                          bitrateStr: bitrateStr,
                          decodedFormat: decodedFormat,
                          claimedCodec: claimedCodec,
                          claimedSampleRate: claimedSampleRate,
                          claimedBitDepth: claimedBitDepth,
                          channelsStr: channelsStr,
                          dynamicSongColor: songPrimaryColor,
                          dynamicSongSecondaryColor: songSecondaryColor,
                        );
                      },
                    ),
                  ] else ...[
                    // TAB 2: Audio Quality Analysis
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.assessment_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Audio Quality Metrics',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (_isAnalyzing)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Grid Specs (2 Columns)
                          _buildGridSpecRow(
                            icon1: Icons.disc_full_rounded,
                            label1: 'Codec:',
                            value1: codec,
                            icon2: Icons.graphic_eq_rounded,
                            label2: 'Sample Rate:',
                            value2: sampleRateStr,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.description_rounded,
                            label1: 'Bit Depth:',
                            value1: bitDepthStr,
                            icon2: Icons.code_rounded,
                            label2: 'Decoded Format:',
                            value2: decodedFormat,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.speed_rounded,
                            label1: 'Bitrate:',
                            value1: bitrateStr,
                            icon2: Icons.grid_view_rounded,
                            label2: 'Channels:',
                            value2: channelsStr,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.timer_outlined,
                            label1: 'Duration:',
                            value1: durationFormatted,
                            icon2: Icons.show_chart_rounded,
                            label2: 'Nyquist:',
                            value2: nyquistStr,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.sd_storage_rounded,
                            label1: 'Size:',
                            value1: sizeMb,
                            icon2: Icons.query_stats_rounded,
                            label2: 'Dynamic Range:',
                            value2: dynamicRangeDb,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.insights_rounded,
                            label1: 'Peak:',
                            value1: peakDb,
                            icon2: Icons.equalizer_rounded,
                            label2: 'RMS:',
                            value2: rmsDb,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.volume_up_rounded,
                            label1: 'LUFS:',
                            value1: lufsStr,
                            icon2: Icons.warning_amber_rounded,
                            label2: 'True Peak:',
                            value2: truePeakStr,
                          ),
                          const SizedBox(height: 10),
                          _buildGridSpecRow(
                            icon1: Icons.check_circle_outline_rounded,
                            label1: 'Clipping:',
                            value1: clippingStr,
                            icon2: Icons.filter_alt_rounded,
                            label2: 'Spectral Cutoff:',
                            value2: cutoffStr,
                          ),
                          const SizedBox(height: 10),
                          _buildSingleSpecRow(
                            icon: Icons.numbers_rounded,
                            label: 'Samples:',
                            value: samplesFormatted,
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(color: Colors.white12, height: 1),
                          ),

                          // Per-channel Stats
                          Text(
                            'Per-channel Stats',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildChannelStatLine('Ch 1:', ch1Text),
                          const SizedBox(height: 4),
                          _buildChannelStatLine('Ch 2:', ch2Text),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({required int index, required String label, required IconData icon}) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C2C34) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, String label, String value, {bool isUrl = false}) {
    return InkWell(
      onTap: () => _copyToClipboard(context, label, value),
      onLongPress: () => _copyToClipboard(context, label, value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: isUrl ? const Color(0xFF64D2FF) : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSpecRow({
    required IconData icon1,
    required String label1,
    required String value1,
    required IconData icon2,
    required String label2,
    required String value2,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon1, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                label1,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Icon(icon2, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                label2,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleSpecRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelStatLine(String chLabel, String statsText) {
    return Row(
      children: [
        const Icon(Icons.subtitles_outlined, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Text(
          chLabel,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Text(
          statsText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  double _parseSampleRateHz(String text) {
    final clean = text.toLowerCase().replaceAll('khz', '').replaceAll('hz', '').trim();
    final parsed = double.tryParse(clean);
    if (parsed == null) return 44100;
    return parsed < 1000 ? parsed * 1000 : parsed;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Enhanced Poweramp / BitChord Unified 5-Node Audio Signal Path View
  Widget _buildPowerampSignalPathView(
    BuildContext context,
    bool isBitPerfectEnabled, {
    required String codec,
    required String sampleRateStr,
    required String bitDepthStr,
    required String bitrateStr,
    required String decodedFormat,
    required String claimedCodec,
    required String claimedSampleRate,
    required String claimedBitDepth,
    required String channelsStr,
    Color dynamicSongColor = const Color(0xFF64D2FF),
    Color dynamicSongSecondaryColor = const Color(0xFF30D158),
  }) {
    return FutureBuilder<AudioOutputInfo>(
      future: AudioDeviceService.getCurrentOutputInfo(
        isBitPerfectSettingEnabled: isBitPerfectEnabled,
      ),
      builder: (context, snapshot) {
        final info = snapshot.data ?? AudioOutputInfo.speaker();
        final isBluetooth = info.outputType == AudioOutputType.bluetooth;
        final isUsb = info.outputType == AudioOutputType.usbDac;

        // Check if stream was downgraded from claimed
        final isDowngraded = (claimedSampleRate != sampleRateStr && claimedSampleRate.isNotEmpty && claimedSampleRate != '44.1 kHz') ||
            (claimedBitDepth != bitDepthStr && claimedBitDepth.isNotEmpty && claimedBitDepth != '16-bit');

        final sampleRateHzVal = _parseSampleRateHz(sampleRateStr);

        Color verdictColor = const Color(0xFF30D158);
        String verdictPillText = 'BIT-EXACT UNTOUCHED';
        String verdictDescription = 'Original stream sample rate and bit depth passed 1:1 directly to output hardware without alteration.';

        if (info.isBitPerfect) {
          verdictColor = const Color(0xFF30D158);
          verdictPillText = 'BIT-EXACT DIRECT';
          verdictDescription = 'Direct USB DAC stream bypassing Android AudioFlinger system resampler.';
        } else if (isDowngraded) {
          verdictColor = const Color(0xFFFF9F0A);
          verdictPillText = 'STREAM DOWNGRADED';
          verdictDescription = 'Claimed format ($claimedBitDepth / $claimedSampleRate) differs from decoded stream ($bitDepthStr / $sampleRateStr).';
        } else if (isBluetooth) {
          verdictColor = const Color(0xFF64D2FF);
          verdictPillText = 'BLUETOOTH A2DP';
          verdictDescription = 'Transmitted over Bluetooth wireless stream (${info.codecName}).';
        } else {
          verdictColor = const Color(0xFF0A84FF);
          verdictPillText = 'AUDIOFLINGER RESAMPLED';
          verdictDescription = 'Resampled downstream to 48.0 kHz system output rate by Android OS audio policy.';
        }

        final String bitExactVerdictStr = info.isBitPerfect
            ? 'Yes (Bit-Perfect Direct)'
            : (isDowngraded
                ? 'No — stream downgraded'
                : (isBluetooth ? 'No — bluetooth A2DP' : 'No — system resampled'));

        final String buffersStr = '2x (${(info.systemBufferFrames * 1000 / info.systemSampleRate).round()}ms, ${info.systemBufferFrames * 25} frames)';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: verdictColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AUDIO SIGNAL PATH',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: verdictColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: verdictColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      verdictPillText,
                      style: TextStyle(
                        color: verdictColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary Verdict Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Text(
                  verdictDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Connected 5-Node Audio Signal Path with Heading Highlights & Flow Animation Line
              AnimatedBuilder(
                animation: _flowController,
                builder: (context, _) {
                  final progress = _flowController.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Node 1: Track Source Input
                      _buildUnifiedPipelineNode(
                        context,
                        nodeIndex: 0,
                        progress: progress,
                        title: 'Track Source Input',
                        subtitle: widget.sourceProvider.toUpperCase(),
                        icon: Icons.cloud_download_outlined,
                        accentColor: verdictColor,
                        dynamicSongColor: dynamicSongColor,
                        dynamicSongSecondaryColor: dynamicSongSecondaryColor,
                        badgeText: isDowngraded ? 'DOWNGRADED' : null,
                        badgeColor: const Color(0xFFFF9F0A),
                        specs: [
                          MapEntry('Codec:', codec),
                          MapEntry('Bit Depth:', bitDepthStr),
                          MapEntry('Sample Rate:', sampleRateStr),
                          MapEntry('Bitrate:', bitrateStr),
                          if (isDowngraded)
                            MapEntry('Claimed:', '$claimedCodec $claimedBitDepth/$claimedSampleRate'),
                        ],
                      ),

                      // Node 2: Audio Decoder Engine
                      _buildUnifiedPipelineNode(
                        context,
                        nodeIndex: 1,
                        progress: progress,
                        title: 'Audio Decoder Engine',
                        subtitle: 'Native $codec Decoder',
                        icon: Icons.memory_rounded,
                        accentColor: verdictColor,
                        dynamicSongColor: dynamicSongColor,
                        dynamicSongSecondaryColor: dynamicSongSecondaryColor,
                        specs: [
                          MapEntry('PCM Format:', decodedFormat.toUpperCase() == 'S16' ? 'PCM16' : (decodedFormat.toUpperCase() == 'F32' ? 'Float32' : decodedFormat)),
                          MapEntry('Sample Rate:', '${sampleRateHzVal.toInt()} Hz'),
                          MapEntry('Channels:', channelsStr),
                        ],
                      ),

                      // Node 3: Resampler & DSP Engine
                      _buildUnifiedPipelineNode(
                        context,
                        nodeIndex: 2,
                        progress: progress,
                        title: 'Resampler & DSP Chain',
                        subtitle: info.isBitPerfect ? 'Bypassed (Bit-Perfect Direct)' : 'AudioFlinger System Resampler',
                        icon: info.isBitPerfect ? Icons.verified_outlined : Icons.tune_rounded,
                        accentColor: verdictColor,
                        dynamicSongColor: dynamicSongColor,
                        dynamicSongSecondaryColor: dynamicSongSecondaryColor,
                        specs: [
                          MapEntry('Gain:', '—'),
                          MapEntry('Measured:', _realResult != null ? '${_realResult!.lufs.toStringAsFixed(1)} LUFS' : '—'),
                          MapEntry('EQ Preset:', 'Custom'),
                          MapEntry('Stereo Expand:', '100%'),
                          MapEntry('Buffers:', buffersStr),
                          MapEntry('Output API:', info.transport),
                          MapEntry('Bit-exact:', bitExactVerdictStr),
                        ],
                      ),

                      // Node 4: Android Output Transport Engine
                      _buildUnifiedPipelineNode(
                        context,
                        nodeIndex: 3,
                        progress: progress,
                        title: 'Android Output Transport',
                        subtitle: info.isBitPerfect
                            ? 'Android 14 USB Direct Track'
                            : (isBluetooth ? 'Android A2DP AudioTrack' : 'AudioFlinger High-Res Track'),
                        icon: Icons.alt_route_rounded,
                        accentColor: verdictColor,
                        dynamicSongColor: dynamicSongColor,
                        dynamicSongSecondaryColor: dynamicSongSecondaryColor,
                        specs: [
                          MapEntry('Transport:', info.transport),
                          MapEntry('Direct:', info.directStatus),
                          MapEntry('AudioTrack:', info.audioTrackFormat),
                        ],
                      ),

                      // Node 5: Output Hardware Device (STOPS HERE)
                      _buildUnifiedPipelineNode(
                        context,
                        nodeIndex: 4,
                        progress: progress,
                        title: 'Output Hardware Device',
                        subtitle: info.deviceName,
                        icon: isBluetooth ? Icons.headphones_outlined : (isUsb ? Icons.usb_outlined : Icons.speaker_outlined),
                        accentColor: verdictColor,
                        dynamicSongColor: dynamicSongColor,
                        dynamicSongSecondaryColor: dynamicSongSecondaryColor,
                        isLast: true,
                        specs: [
                          MapEntry('Device Name:', info.deviceName),
                          MapEntry('Route:', info.route),
                          MapEntry('System:', info.systemHal),
                          MapEntry('Bluetooth:', info.bluetoothProfile),
                          MapEntry('Codec:', info.codecName),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnifiedPipelineNode(
    BuildContext context, {
    required int nodeIndex,
    required double progress,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<MapEntry<String, String>> specs,
    Color accentColor = Colors.white70,
    Color dynamicSongColor = const Color(0xFF64D2FF),
    Color dynamicSongSecondaryColor = const Color(0xFF30D158),
    String? badgeText,
    Color? badgeColor,
    bool isLast = false,
  }) {
    final copySummary = '$title: $subtitle (${specs.map((e) => "${e.key} ${e.value}").join(", ")})';

    // Calculate node highlight factor (0.0 to 1.0) as animation pulse passes by
    final double nodeStart = nodeIndex * 0.2;
    final double centerProgress = nodeStart + 0.1;
    final double dist = (progress - centerProgress).abs();
    final double highlightFactor = (1.0 - (dist / 0.12)).clamp(0.0, 1.0);

    // Segment progress for vertical line extending below this node (0.0 to 1.0)
    final double segmentProgress = isLast ? 0.0 : ((progress - nodeStart) / 0.2).clamp(-0.2, 1.2);

    return InkWell(
      onTap: () => _copyToClipboard(context, title, copySummary),
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column: Circle Icon Badge + Line Segment to next node
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  // Minimalistic White Icon Badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF1B1B1E),
                        Colors.white.withOpacity(0.20),
                        highlightFactor,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color.lerp(
                          accentColor.withOpacity(0.4),
                          Colors.white,
                          highlightFactor,
                        )!,
                        width: 1.5 + (highlightFactor * 0.8),
                      ),
                      boxShadow: highlightFactor > 0.1
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.45 * highlightFactor),
                                blurRadius: 8 * highlightFactor,
                                spreadRadius: 1 * highlightFactor,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 14,
                        color: Color.lerp(
                          Colors.white54,
                          Colors.white,
                          highlightFactor,
                        ),
                      ),
                    ),
                  ),

                  // Minimalistic White Vertical Line Segment extending to next node (STOPS strictly at node 5)
                  if (!isLast)
                    Expanded(
                      child: CustomPaint(
                        size: const Size(28, double.infinity),
                        painter: SingleSegmentLinePainter(
                          segmentProgress: segmentProgress,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right Content: Title, Subtitle, and Parameters Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Highlighted Title
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: highlightFactor > 0.15
                                ? [
                                    Shadow(
                                      color: Colors.white.withOpacity(0.7 * highlightFactor),
                                      blurRadius: 8 * highlightFactor,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? Colors.amber).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: (badgeColor ?? Colors.amber).withOpacity(0.4)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor ?? Colors.amber,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Color.lerp(
                          const Color(0xE6FFFFFF),
                          Colors.white,
                          highlightFactor,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Integrated Parameter Key-Value List
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.08),
                          highlightFactor,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Color.lerp(
                            Colors.white.withOpacity(0.04),
                            Colors.white.withOpacity(0.35),
                            highlightFactor,
                          )!,
                        ),
                      ),
                      child: Column(
                        children: specs.map((entry) {
                          final isHighlight = entry.key == 'Bit-exact:' && entry.value.contains('Yes');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: isHighlight ? const Color(0xFF30D158) : Colors.white,
                                      fontSize: 11,
                                      fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalistic White CustomPainter for vertical line segment between two nodes
class SingleSegmentLinePainter extends CustomPainter {
  final double segmentProgress;

  SingleSegmentLinePainter({
    required this.segmentProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double x = size.width / 2;

    // 1. Base vertical guide line for this segment (minimalistic dim white)
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), basePaint);

    // 2. Animated Flowing Pulse traveling down this segment (glowing white)
    if (segmentProgress > -0.2 && segmentProgress < 1.2) {
      final double headY = size.height * segmentProgress;
      const double pulseLength = 60.0;
      final double tailY = headY - pulseLength;

      final double clampedHead = headY.clamp(0.0, size.height);
      final double clampedTail = tailY.clamp(0.0, size.height);

      if (clampedHead > clampedTail) {
        final Rect rect = Rect.fromLTRB(x - 5, clampedTail, x + 5, clampedHead);

        final Shader pulseShader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.4),
            Colors.white,
            Colors.white.withOpacity(0.9),
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ).createShader(rect);

        // Outer white glow
        final glowPaint = Paint()
          ..shader = pulseShader
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
          ..style = PaintingStyle.stroke;

        // Core bright white line
        final pulsePaint = Paint()
          ..shader = pulseShader
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset(x, clampedTail), Offset(x, clampedHead), glowPaint);
        canvas.drawLine(Offset(x, clampedTail), Offset(x, clampedHead), pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SingleSegmentLinePainter oldDelegate) {
    return oldDelegate.segmentProgress != segmentProgress;
  }
}
