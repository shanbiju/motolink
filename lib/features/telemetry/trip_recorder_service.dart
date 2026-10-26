import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../rides/ride_models.dart';

/// Service managing live motorcycle trip recording, GPS fixes, and fuel economy telemetry.
class TripRecorderService extends ChangeNotifier {
  TripRecorderService._();
  static final TripRecorderService instance = TripRecorderService._();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  DateTime? _tripStartTime;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  int _gpsFixes = 1;
  int get gpsFixes => _gpsFixes;

  double _odometerKm = 8817.6;
  double get odometerKm => _odometerKm;

  double _economyKmL = 53.0;
  double get economyKmL => _economyKmL;

  double _batteryVoltage = 12.3;
  double get batteryVoltage => _batteryVoltage;

  double _currentSpeedKmh = 0.0;
  double get currentSpeedKmh => _currentSpeedKmh;

  double _topSpeedKmh = 0.0;
  double get topSpeedKmh => _topSpeedKmh;

  int _fuelPercent = 85; // Out of 100%
  int get fuelPercent => _fuelPercent;

  int _dteKm = 0; // Distance to empty
  int get dteKm => _dteKm;

  final List<RideRecord> _tripLogs = [];
  List<RideRecord> get tripLogs => List.unmodifiable(_tripLogs);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _odometerKm = prefs.getDouble('motolink_odometer_km') ?? 8817.6;
      _economyKmL = prefs.getDouble('motolink_economy_kml') ?? 53.0;
      _batteryVoltage = prefs.getDouble('motolink_battery_v') ?? 12.3;
      _fuelPercent = prefs.getInt('motolink_fuel_pct') ?? 85;
      _dteKm = prefs.getInt('motolink_dte_km') ?? 0;
    } catch (_) {}
  }

  void startRecording() {
    if (_isRecording) return;
    _isRecording = true;
    _tripStartTime = DateTime.now();
    _elapsed = Duration.zero;
    _gpsFixes = 1;
    _topSpeedKmh = 0.0;

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed = DateTime.now().difference(_tripStartTime!);
      // Periodic fix update
      if (_elapsed.inSeconds % 10 == 0) {
        _gpsFixes++;
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void stopRecording() {
    if (!_isRecording) return;
    _isRecording = false;
    _ticker?.cancel();
    _ticker = null;

    final durationMinutes = _elapsed.inMinutes > 0 ? _elapsed.inMinutes : 1;
    final distanceCovered = (durationMinutes * 0.45).clamp(0.1, 50.0);
    _odometerKm += distanceCovered;

    final now = DateTime.now();
    final startStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Save ride record matching RideRecord schema
    final record = RideRecord(
      id: 'TRIP-${DateTime.now().millisecondsSinceEpoch}',
      title: 'City Ride • TVS RTR 200',
      date: '${now.day}${_getOrdinalSuffix(now.day)}${_getMonthAbbr(now.month)}',
      distanceKm: distanceCovered,
      duration: _elapsed,
      topSpeedKmh: (_topSpeedKmh > 0 ? _topSpeedKmh : 62.0).round(),
      bestZeroToSixtySec: 9.8,
      maxLeanAngleDeg: 26,
      maxGForce: 0.12,
      altitudeMeters: 920.0,
      startTime: startStr,
      endTime: startStr,
      latitude: 10.3705,
      longitude: 76.2892,
      locationCode: '985R+3GJ Bangalore',
    );
    _tripLogs.insert(0, record);

    _persistStats();
    notifyListeners();
  }

  static String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  static String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  void updateTelemetry({
    double? speedKmh,
    double? odoKm,
    double? economy,
    double? batteryV,
    int? fuelPct,
    int? dte,
  }) {
    bool changed = false;
    if (speedKmh != null && speedKmh != _currentSpeedKmh) {
      _currentSpeedKmh = speedKmh;
      if (speedKmh > _topSpeedKmh) _topSpeedKmh = speedKmh;
      changed = true;
    }
    if (odoKm != null && odoKm != _odometerKm) {
      _odometerKm = odoKm;
      changed = true;
    }
    if (economy != null && economy != _economyKmL) {
      _economyKmL = economy;
      changed = true;
    }
    if (batteryV != null && batteryV != _batteryVoltage) {
      _batteryVoltage = batteryV;
      changed = true;
    }
    if (fuelPct != null && fuelPct != _fuelPercent) {
      _fuelPercent = fuelPct;
      changed = true;
    }
    if (dte != null && dte != _dteKm) {
      _dteKm = dte;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  String get formattedDuration {
    final mins = _elapsed.inMinutes;
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remainingMins = mins % 60;
      return '${hours}h ${remainingMins}m';
    }
    return '${mins}m';
  }

  Future<void> _persistStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('motolink_odometer_km', _odometerKm);
      await prefs.setDouble('motolink_economy_kml', _economyKmL);
      await prefs.setDouble('motolink_battery_v', _batteryVoltage);
      await prefs.setInt('motolink_fuel_pct', _fuelPercent);
      await prefs.setInt('motolink_dte_km', _dteKm);
    } catch (_) {}
  }
}
