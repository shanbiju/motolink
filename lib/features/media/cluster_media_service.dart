import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ble/ble_connection_manager.dart';
import '../../core/ble/ble_models.dart';

/// Service managing cluster media display (Now Playing song) and 5G network signal sync
/// to the TVS Apache RTR 200 / SmartXonnect instrument cluster.
class ClusterMediaService extends ChangeNotifier {
  ClusterMediaService._();
  static final ClusterMediaService instance = ClusterMediaService._();

  static const String _prefTrackKey = 'motolink_current_track';
  static const String _prefArtistKey = 'motolink_current_artist';
  static const String _prefNetworkKey = 'motolink_network_type';

  String _currentTrack = 'Blinding Lights';
  String _currentArtist = 'The Weeknd';
  bool _isPlaying = true;

  // 5G Network and Phone Battery sync state
  String _networkType = '5G';
  int _signalBars = 5; // Fixed 5 bars for 5G (resolves official TVS bug showing 0 bars on 5G)
  int _batteryPercent = 87;

  bool _isNavActive = false;
  DateTime? _lastNavPacketTime;

  Timer? _clusterSyncTimer;
  BleConnectionManager? _bleManager;

  String get currentTrack => _currentTrack;
  String get currentArtist => _currentArtist;
  bool get isPlaying => _isPlaying;
  String get networkType => _networkType;
  int get signalBars => _signalBars;
  int get batteryPercent => _batteryPercent;
  bool get isNavActive => _isNavActive;

  /// Cluster LCD 15-character formatted display text
  String get clusterFormattedTrack {
    final raw = 'SONG: ${_currentTrack.toUpperCase()}';
    if (raw.length > 15) {
      return raw.substring(0, 15);
    }
    return raw.padRight(15, ' ');
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentTrack = prefs.getString(_prefTrackKey) ?? 'Blinding Lights';
      _currentArtist = prefs.getString(_prefArtistKey) ?? 'The Weeknd';
      _networkType = prefs.getString(_prefNetworkKey) ?? '5G';
    } catch (_) {}
    notifyListeners();
  }

  /// Attach BLE manager and start background heartbeat sync to cluster
  void attachBleManager(BleConnectionManager manager) {
    _bleManager = manager;
    _clusterSyncTimer?.cancel();
    // Sync to cluster every 8 seconds when connected
    _clusterSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      syncToCluster();
    });
  }

  void detachBleManager() {
    _clusterSyncTimer?.cancel();
    _clusterSyncTimer = null;
    _bleManager = null;
  }

  /// Updates current playing track and dispatches to cluster if navigation is idle
  void updateMedia({
    required String trackTitle,
    required String artist,
    bool? isPlaying,
  }) {
    _currentTrack = trackTitle.trim().isNotEmpty ? trackTitle.trim() : 'Playing Track';
    _currentArtist = artist.trim().isNotEmpty ? artist.trim() : 'Media Player';
    if (isPlaying != null) _isPlaying = isPlaying;

    _saveMediaPrefs();
    notifyListeners();
    syncToCluster(forceText: true);
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
    syncToCluster(forceText: true);
  }

  void nextTrack() {
    // Quick demo rotation or skip
    if (_currentTrack.contains('Blinding')) {
      _currentTrack = 'Starboy';
      _currentArtist = 'The Weeknd';
    } else if (_currentTrack.contains('Starboy')) {
      _currentTrack = 'Believer';
      _currentArtist = 'Imagine Dragons';
    } else {
      _currentTrack = 'Blinding Lights';
      _currentArtist = 'The Weeknd';
    }
    _isPlaying = true;
    _saveMediaPrefs();
    notifyListeners();
    syncToCluster(forceText: true);
  }

  void previousTrack() {
    if (_currentTrack.contains('Believer')) {
      _currentTrack = 'Starboy';
      _currentArtist = 'The Weeknd';
    } else {
      _currentTrack = 'Blinding Lights';
      _currentArtist = 'The Weeknd';
    }
    _isPlaying = true;
    _saveMediaPrefs();
    notifyListeners();
    syncToCluster(forceText: true);
  }

  /// Sets navigation activity state. While navigation is active, media text is suppressed
  void notifyNavigationDispatched() {
    _isNavActive = true;
    _lastNavPacketTime = DateTime.now();
    notifyListeners();
  }

  void setNavActive(bool active) {
    _isNavActive = active;
    notifyListeners();
  }

  /// Updates 5G network status and signal bars
  void updateNetworkAndBattery({
    String? network,
    int? bars,
    int? battery,
  }) {
    if (network != null) _networkType = network;
    // On 5G network, always ensure full signal bars (4 or 5) so cluster never shows "no network"
    if (network != null && network.toUpperCase().contains('5G')) {
      _signalBars = 5;
    } else if (bars != null) {
      _signalBars = bars.clamp(0, 5);
    }
    if (battery != null) _batteryPercent = battery.clamp(0, 100);

    notifyListeners();
    syncPhoneStatusToCluster();
  }

  /// Sends phone state (battery + 5G signal bars) to the cluster
  Future<bool> syncPhoneStatusToCluster() async {
    if (_bleManager == null || !_bleManager!.stage.isConnected) return false;

    // 5G guaranteed bars (5 bars) so the speedometer network icon is fully lit
    final barsToSend = _networkType.toUpperCase().contains('5G') ? 5 : _signalBars;

    return await _bleManager!.dispatchPhoneStatus(
      batteryPercent: _batteryPercent,
      signalStrengthBars: barsToSend,
    );
  }

  /// Syncs current media song title to the LCD cluster ribbon if no turn-by-turn is active
  Future<bool> syncToCluster({bool forceText = false}) async {
    if (_bleManager == null || !_bleManager!.stage.isConnected) return false;

    // First ensure 5G signal bars and battery are transmitted
    await syncPhoneStatusToCluster();

    // Check if recent navigation was dispatched within the last 15 seconds
    if (_lastNavPacketTime != null) {
      final diff = DateTime.now().difference(_lastNavPacketTime!).inSeconds;
      if (diff < 15) {
        _isNavActive = true;
        // Navigation has priority on the cluster LCD
        return false;
      } else {
        _isNavActive = false;
      }
    }

    if (_isNavActive && !forceText) {
      return false;
    }

    // When no active turn instruction, send the current playing song to the cluster!
    final textToSend = _isPlaying ? clusterFormattedTrack : 'PAUSED         ';
    debugPrint('[Cluster Display] Transmitting to cluster ribbon: "$textToSend"');
    return await _bleManager!.dispatchText(textToSend, line: 1);
  }

  Future<void> _saveMediaPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTrackKey, _currentTrack);
      await prefs.setString(_prefArtistKey, _currentArtist);
      await prefs.setString(_prefNetworkKey, _networkType);
    } catch (_) {}
  }
}
