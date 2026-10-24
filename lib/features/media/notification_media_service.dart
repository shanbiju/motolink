import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cluster_media_service.dart';

/// Service connecting to native Android NotificationListenerService to
/// automatically extract currently playing song/artist from Spotify, YouTube Music,
/// Apple Music, Wynk, SoundCloud, etc., and pipe it directly to TVS cluster.
class NotificationMediaService extends ChangeNotifier {
  NotificationMediaService._();
  static final NotificationMediaService instance = NotificationMediaService._();

  static const MethodChannel _channel = MethodChannel('com.motolink.app/media');

  bool _isListening = false;
  bool _hasPermission = false;
  String _activeSourceApp = 'Spotify / Media';

  bool get isListening => _isListening;
  bool get hasPermission => _hasPermission;
  String get activeSourceApp => _activeSourceApp;

  Future<void> init() async {
    _channel.setMethodCallHandler(_handleNativeCall);
    await checkPermission();
  }

  Future<bool> checkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('isNotificationAccessGranted');
      _hasPermission = granted ?? false;
      _isListening = _hasPermission;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[NotificationMediaService] checkPermission error: $e');
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('[NotificationMediaService] openSettings error: $e');
    }
  }

  Future<void> fetchLastTrack() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('getLastTrack');
      if (data != null) {
        final title = data['title'] as String? ?? '';
        final artist = data['artist'] as String? ?? '';
        final isPlaying = data['isPlaying'] as bool? ?? true;
        if (title.isNotEmpty) {
          ClusterMediaService.instance.updateMedia(
            trackTitle: title,
            artist: artist,
            isPlaying: isPlaying,
          );
        }
      }
    } catch (_) {}
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onMediaTrackReceived') {
      try {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final title = args['title'] as String? ?? '';
        final artist = args['artist'] as String? ?? '';
        final isPlaying = args['isPlaying'] as bool? ?? true;
        final source = args['source'] as String? ?? 'Media Player';

        if (title.isNotEmpty) {
          _activeSourceApp = _formatSourceName(source);
          notifyListeners();

          debugPrint('[Media Notification] Received: "$title" by "$artist" ($source)');
          ClusterMediaService.instance.updateMedia(
            trackTitle: title,
            artist: artist,
            isPlaying: isPlaying,
          );
        }
      } catch (e) {
        debugPrint('[NotificationMediaService] Error processing track callback: $e');
      }
    }
  }

  String _formatSourceName(String pkg) {
    final lower = pkg.toLowerCase();
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('youtube')) return 'YouTube Music';
    if (lower.contains('apple')) return 'Apple Music';
    if (lower.contains('wynk')) return 'Wynk Music';
    if (lower.contains('jiosaavn') || lower.contains('saavn')) return 'JioSaavn';
    if (lower.contains('gaana')) return 'Gaana';
    if (lower.contains('soundcloud')) return 'SoundCloud';
    return 'Music Player';
  }
}
