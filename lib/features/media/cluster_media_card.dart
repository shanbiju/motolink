import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'cluster_media_service.dart';
import 'notification_media_service.dart';

class ClusterMediaCard extends StatefulWidget {
  final bool isConnected;

  const ClusterMediaCard({
    super.key,
    required this.isConnected,
  });

  @override
  State<ClusterMediaCard> createState() => _ClusterMediaCardState();
}

class _ClusterMediaCardState extends State<ClusterMediaCard> {
  final _mediaService = ClusterMediaService.instance;
  final _notifService = NotificationMediaService.instance;
  late final TextEditingController _customTrackController;
  bool _isEditingTrack = false;
  bool _dismissNotifBanner = false;

  @override
  void initState() {
    super.initState();
    _customTrackController = TextEditingController(text: _mediaService.currentTrack);
    _mediaService.addListener(_onServiceUpdate);
    _notifService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _customTrackController.dispose();
    _mediaService.removeListener(_onServiceUpdate);
    _notifService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      if (!_isEditingTrack) {
        _customTrackController.text = _mediaService.currentTrack;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = _mediaService.currentTrack;
    final artist = _mediaService.currentArtist;
    final isPlaying = _mediaService.isPlaying;
    final isNavActive = _mediaService.isNavActive;
    final lcdText = isNavActive
        ? 'NAV: TURN ACTIVE'
        : (isPlaying ? _mediaService.clusterFormattedTrack : 'PAUSED         ');

    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.surfaceOf(context);
    final textCol = AppColors.textOf(context);
    final mutedCol = AppColors.textMutedOf(context);
    final accentCol = AppColors.accentOf(context);
    final borderCol = AppColors.borderOf(context);

    final hasNotifPermission = _notifService.hasPermission;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + 5G NETWORK & CLUSTER MEDIA + 5G Live Badge
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLightOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note, color: accentCol, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLUSTER MEDIA & 5G',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '14-Seg LCD Ribbon • TVS 5G Fix',
                      style: TextStyle(
                        color: mutedCol,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // 5G Network Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentCol.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentCol.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.network_cell, color: accentCol, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '5G (5 BARS)',
                      style: TextStyle(
                        color: accentCol,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasNotifPermission || !_dismissNotifBanner) ...[
            const SizedBox(height: 14),

            // 1. Auto-Fetch from Notifications Banner (Feature requested by user)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hasNotifPermission
                    ? const Color(0xFF1DB954).withOpacity(0.12)
                    : accentCol.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasNotifPermission
                      ? const Color(0xFF1DB954).withOpacity(0.4)
                      : accentCol.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasNotifPermission ? Icons.notifications_active : Icons.notifications_paused_outlined,
                    color: hasNotifPermission ? const Color(0xFF1DB954) : accentCol,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasNotifPermission
                              ? 'Auto-Fetch from Music Notifications'
                              : 'Fetch Music Notifications (Optional)',
                          style: TextStyle(
                            color: textCol,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasNotifPermission
                              ? 'Actively listening to ${_notifService.activeSourceApp}. Real-time track piped to cluster.'
                              : 'Sync Spotify/YT Music automatically, or use manual input below.',
                          style: TextStyle(color: mutedCol, fontSize: 9.5, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: hasNotifPermission ? const Color(0xFF1DB954) : accentCol,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      if (hasNotifPermission) {
                        await _notifService.fetchLastTrack();
                      } else {
                        await _notifService.openSettings();
                      }
                    },
                    child: Text(
                      hasNotifPermission ? 'SYNC NOW' : 'ENABLE',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                  if (!hasNotifPermission) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Use Manual Mode without permission',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: Icon(Icons.close, color: mutedCol, size: 16),
                      onPressed: () => setState(() => _dismissNotifBanner = true),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // 2. 5G Network Bug Fixed Note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLightOf(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF00B4D8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '5G "No Network" Bug Solved: Full 5-bar reception actively sent via Opcode 0x05 to speedometer.',
                    style: TextStyle(color: mutedCol, fontSize: 9.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Sync 5G & Battery to Cluster',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(Icons.sync, color: accentCol, size: 16),
                  onPressed: () async {
                    final sent = await _mediaService.syncPhoneStatusToCluster();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? '5G Signal (5 Bars) & Battery (${_mediaService.batteryPercent}%) synced to cluster!'
                                : 'Connect via Bluetooth to sync 5G signal.',
                          ),
                          backgroundColor: sent ? accentCol : Colors.grey[800],
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Bike Cluster LCD 14-Segment Display Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF070B0E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNavActive ? Colors.orangeAccent.withOpacity(0.6) : accentCol.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isNavActive ? Colors.orangeAccent : accentCol).withOpacity(0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BIKE LCD 14-SEGMENT TEXT RIBBON',
                      style: TextStyle(
                        color: isNavActive ? Colors.orangeAccent : accentCol,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNavActive ? Colors.orangeAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isNavActive ? 'PRIORITY: MAP' : 'PRIORITY: SONG',
                        style: TextStyle(
                          color: isNavActive ? Colors.orangeAccent : Colors.greenAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        lcdText,
                        style: const TextStyle(
                          color: Color(0xFFE2F1AF), // Vintage TVS LCD segment yellow-green
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    isNavActive
                        ? 'Navigation turn active. Media suppressed on speedometer until cruising.'
                        : 'Updated on bike cluster speedometer every 8s when navigation is idle.',
                    style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Current Song Details & Controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedCol,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Playback buttons
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: textCol, size: 24),
                onPressed: () => _mediaService.previousTrack(),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: accentCol,
                  size: 36,
                ),
                onPressed: () => _mediaService.togglePlayPause(),
              ),
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: textCol, size: 24),
                onPressed: () => _mediaService.nextTrack(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5. Handlebar i-Button Integration Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceLightOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.radio_button_checked, color: accentCol, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Handlebar i-Button: 1x Play/Pause • 2x Prev • 3x Next',
                    style: TextStyle(
                      color: textCol,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() => _isEditingTrack = !_isEditingTrack);
                  },
                  child: Text(
                    _isEditingTrack ? 'CLOSE' : 'MANUAL',
                    style: TextStyle(
                      color: accentCol,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom Song Name Editor
          if (_isEditingTrack) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTrackController,
                    style: TextStyle(color: textCol, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter song title (e.g. Starboy)',
                      hintStyle: TextStyle(color: mutedCol, fontSize: 11),
                      filled: true,
                      fillColor: AppColors.bgOf(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: accentCol),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentCol,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final title = _customTrackController.text.trim();
                    if (title.isNotEmpty) {
                      _mediaService.updateMedia(trackTitle: title, artist: 'Now Playing');
                      setState(() => _isEditingTrack = false);
                    }
                  },
                  child: const Text('SET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
