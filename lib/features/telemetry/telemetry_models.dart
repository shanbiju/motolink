enum RideMode {
  urban,
  sport,
  rain,
  track,
}

extension RideModeExtension on RideMode {
  String get displayName {
    switch (this) {
      case RideMode.urban:
        return 'URBAN';
      case RideMode.sport:
        return 'SPORT';
      case RideMode.rain:
        return 'RAIN';
      case RideMode.track:
        return 'TRACK';
    }
  }
}

/// Comprehensive vehicle telemetry state parsed from instrument cluster notifications.
class TelemetryData {
  // Speedometer & Engine (Frame 0x10)
  final double speedKmh;
  final int engineRpm;
  final double odometerKm;
  final double topSpeedKmh;
  final double averageSpeedKmh;
  final double instantMileageKml;
  final int throttlePercent;
  final int fuelLevelPercent;
  final double tripFMeterKm;
  final int zeroToSixtyMs;

  // Dynamics & Vehicle State (Frame 0x11)
  final int gear; // 0 = Neutral, 1-6 = Gears
  final double engineTempC;
  final double batteryVoltage;
  final RideMode rideMode;
  final bool isSideStandDown;
  final bool isClutchPulled;
  final bool isBrakeActive;
  final bool isKillSwitchActive;
  final bool isElectricStartActive;
  final bool isTurnSignalLeft;
  final bool isTurnSignalRight;
  final bool isAbsMilActive;
  final int clusterSoftwareVersion;

  // Dynamics & Angle (Frame 0x12)
  final int leanAngleDegrees; // negative = left, positive = right
  final double accelerationG;
  final int distanceToEmptyKm;
  final double instantTorqueNm;
  final double tripDistanceKm;
  final Duration tripDuration;
  final double tripFuelLiters;

  // Race / Lap Telemetry (Frame 0x16)
  final bool isLapTriggered;
  final int currentLapNumber;
  final Duration currentLapTime;
  final int bestLapNumber;
  final Duration bestLapTime;

  // Diagnostics (Frame 0x18)
  final int intakeAirTempC;
  final double manifoldPressureBar;
  final Duration engineRunTime;

  // TPMS (Frame 0x5F)
  final double? frontTyrePsi;
  final double? rearTyrePsi;
  final int? frontTyreTempC;
  final int? rearTyreTempC;
  final int? frontTyreBattery;
  final int? rearTyreBattery;

  // Handlebar Switches & i-Button (Call Accept / Reject / Mode / Custom Action)
  final int callAcceptRejectStatus; // 0 = idle, 1 = accept / short click, 2 = reject / cancel / i-button
  final bool isVoiceAssistInvoked;
  final bool isIButtonPressed;

  final DateTime timestamp;

  const TelemetryData({
    this.callAcceptRejectStatus = 0,
    this.isVoiceAssistInvoked = false,
    this.isIButtonPressed = false,
    this.speedKmh = 0.0,
    this.engineRpm = 0,
    this.odometerKm = 0.0,
    this.topSpeedKmh = 0.0,
    this.averageSpeedKmh = 0.0,
    this.instantMileageKml = 0.0,
    this.throttlePercent = 0,
    this.fuelLevelPercent = 85,
    this.tripFMeterKm = 0.0,
    this.zeroToSixtyMs = 0,
    this.gear = 0,
    this.engineTempC = 0.0,
    this.batteryVoltage = 12.6,
    this.rideMode = RideMode.sport,
    this.isSideStandDown = false,
    this.isClutchPulled = false,
    this.isBrakeActive = false,
    this.isKillSwitchActive = false,
    this.isElectricStartActive = false,
    this.isTurnSignalLeft = false,
    this.isTurnSignalRight = false,
    this.isAbsMilActive = false,
    this.clusterSoftwareVersion = 1,
    this.leanAngleDegrees = 0,
    this.accelerationG = 0.0,
    this.distanceToEmptyKm = 240,
    this.instantTorqueNm = 0.0,
    this.tripDistanceKm = 0.0,
    this.tripDuration = Duration.zero,
    this.tripFuelLiters = 0.0,
    this.isLapTriggered = false,
    this.currentLapNumber = 0,
    this.currentLapTime = Duration.zero,
    this.bestLapNumber = 0,
    this.bestLapTime = Duration.zero,
    this.intakeAirTempC = 28,
    this.manifoldPressureBar = 1.0,
    this.engineRunTime = Duration.zero,
    this.frontTyrePsi = 32.0,
    this.rearTyrePsi = 36.0,
    this.frontTyreTempC = 30,
    this.rearTyreTempC = 33,
    this.frontTyreBattery = 95,
    this.rearTyreBattery = 92,
    required this.timestamp,
  });

  bool get isNeutral => gear == 0;
  String get gearDisplay => isNeutral ? 'N' : gear.toString();
  bool get hasIButtonEvent => isIButtonPressed || callAcceptRejectStatus != 0 || isVoiceAssistInvoked;

  /// Average mileage calculated from trip telemetry or TVS Apache RTR 200 fuel curve
  double get averageMileageKml {
    if (tripFuelLiters > 0 && tripDistanceKm > 0) {
      return (tripDistanceKm / tripFuelLiters).clamp(10.0, 75.0);
    }
    if (instantMileageKml > 0) {
      return (instantMileageKml * 0.94).clamp(20.0, 60.0);
    }
    return 42.5; // RTR 200 4V standard average mileage (km/L)
  }

  TelemetryData copyWith({
    int? callAcceptRejectStatus,
    bool? isVoiceAssistInvoked,
    bool? isIButtonPressed,
    double? speedKmh,
    int? engineRpm,
    double? odometerKm,
    double? topSpeedKmh,
    double? averageSpeedKmh,
    double? instantMileageKml,
    int? throttlePercent,
    int? fuelLevelPercent,
    double? tripFMeterKm,
    int? zeroToSixtyMs,
    int? gear,
    double? engineTempC,
    double? batteryVoltage,
    RideMode? rideMode,
    bool? isSideStandDown,
    bool? isClutchPulled,
    bool? isBrakeActive,
    bool? isKillSwitchActive,
    bool? isElectricStartActive,
    bool? isTurnSignalLeft,
    bool? isTurnSignalRight,
    bool? isAbsMilActive,
    int? clusterSoftwareVersion,
    int? leanAngleDegrees,
    double? accelerationG,
    int? distanceToEmptyKm,
    double? instantTorqueNm,
    double? tripDistanceKm,
    Duration? tripDuration,
    double? tripFuelLiters,
    bool? isLapTriggered,
    int? currentLapNumber,
    Duration? currentLapTime,
    int? bestLapNumber,
    Duration? bestLapTime,
    int? intakeAirTempC,
    double? manifoldPressureBar,
    Duration? engineRunTime,
    double? frontTyrePsi,
    double? rearTyrePsi,
    int? frontTyreTempC,
    int? rearTyreTempC,
    int? frontTyreBattery,
    int? rearTyreBattery,
    DateTime? timestamp,
  }) {
    return TelemetryData(
      callAcceptRejectStatus: callAcceptRejectStatus ?? this.callAcceptRejectStatus,
      isVoiceAssistInvoked: isVoiceAssistInvoked ?? this.isVoiceAssistInvoked,
      isIButtonPressed: isIButtonPressed ?? this.isIButtonPressed,
      speedKmh: speedKmh ?? this.speedKmh,
      engineRpm: engineRpm ?? this.engineRpm,
      odometerKm: odometerKm ?? this.odometerKm,
      topSpeedKmh: topSpeedKmh ?? this.topSpeedKmh,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      instantMileageKml: instantMileageKml ?? this.instantMileageKml,
      throttlePercent: throttlePercent ?? this.throttlePercent,
      fuelLevelPercent: fuelLevelPercent ?? this.fuelLevelPercent,
      tripFMeterKm: tripFMeterKm ?? this.tripFMeterKm,
      zeroToSixtyMs: zeroToSixtyMs ?? this.zeroToSixtyMs,
      gear: gear ?? this.gear,
      engineTempC: engineTempC ?? this.engineTempC,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      rideMode: rideMode ?? this.rideMode,
      isSideStandDown: isSideStandDown ?? this.isSideStandDown,
      isClutchPulled: isClutchPulled ?? this.isClutchPulled,
      isBrakeActive: isBrakeActive ?? this.isBrakeActive,
      isKillSwitchActive: isKillSwitchActive ?? this.isKillSwitchActive,
      isElectricStartActive: isElectricStartActive ?? this.isElectricStartActive,
      isTurnSignalLeft: isTurnSignalLeft ?? this.isTurnSignalLeft,
      isTurnSignalRight: isTurnSignalRight ?? this.isTurnSignalRight,
      isAbsMilActive: isAbsMilActive ?? this.isAbsMilActive,
      clusterSoftwareVersion: clusterSoftwareVersion ?? this.clusterSoftwareVersion,
      leanAngleDegrees: leanAngleDegrees ?? this.leanAngleDegrees,
      accelerationG: accelerationG ?? this.accelerationG,
      distanceToEmptyKm: distanceToEmptyKm ?? this.distanceToEmptyKm,
      instantTorqueNm: instantTorqueNm ?? this.instantTorqueNm,
      tripDistanceKm: tripDistanceKm ?? this.tripDistanceKm,
      tripDuration: tripDuration ?? this.tripDuration,
      tripFuelLiters: tripFuelLiters ?? this.tripFuelLiters,
      isLapTriggered: isLapTriggered ?? this.isLapTriggered,
      currentLapNumber: currentLapNumber ?? this.currentLapNumber,
      currentLapTime: currentLapTime ?? this.currentLapTime,
      bestLapNumber: bestLapNumber ?? this.bestLapNumber,
      bestLapTime: bestLapTime ?? this.bestLapTime,
      intakeAirTempC: intakeAirTempC ?? this.intakeAirTempC,
      manifoldPressureBar: manifoldPressureBar ?? this.manifoldPressureBar,
      engineRunTime: engineRunTime ?? this.engineRunTime,
      frontTyrePsi: frontTyrePsi ?? this.frontTyrePsi,
      rearTyrePsi: rearTyrePsi ?? this.rearTyrePsi,
      frontTyreTempC: frontTyreTempC ?? this.frontTyreTempC,
      rearTyreTempC: rearTyreTempC ?? this.rearTyreTempC,
      frontTyreBattery: frontTyreBattery ?? this.frontTyreBattery,
      rearTyreBattery: rearTyreBattery ?? this.rearTyreBattery,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory TelemetryData.initial() => TelemetryData(timestamp: DateTime.now());
}
