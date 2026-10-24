import 'dart:typed_data';
import '../core/protocol/frame_parser.dart';
import '../core/protocol/packet_builder.dart';
import '../features/navigation/navigation_models.dart';
import '../features/telemetry/telemetry_models.dart';
import 'vehicle_adapter.dart';

/// Concrete Hardware Adapter for TVS Apache RTR 200 4V (U399 / U400).
class TvsRtr200Adapter implements VehicleAdapter {
  final TvsFrameParser _frameParser = TvsFrameParser();

  @override
  String get modelName => 'TVS Apache RTR 200 4V';

  @override
  String get platformCode => 'U399';

  @override
  List<String> get advertisedNamePrefixes => const [
        'RMB',
        'TI',
        'TI05',
        'TVS',
        'RTR',
        'RTR 200',
        'RTR200',
        'SmartXonnect',
        'Apache',
        'NTORQ',
        'RONIN',
        'RAIDER',
        'JUPITER',
      ];

  @override
  String get serviceUuid => '5456534D-5647-5341-5342-454E544F5251';

  @override
  String get readCharacteristicUuid => '00005354-0000-1000-8000-00805F9B34FB';

  @override
  String get writeCharacteristicUuid => '00005352-0000-1000-8000-00805F9B34FB';

  @override
  int get maxStreetLength => 15;

  @override
  bool get isSegmentedLcd => true;

  @override
  TelemetryData parseTelemetry(Uint8List rawBytes, TelemetryData current) {
    try {
      final frames = _frameParser.feed(rawBytes);
      var state = current;

      for (final frame in frames) {
        state = _processFrame(frame, state);
      }
      return state;
    } catch (_) {
      // Gracefully handle malformed or unexpected bytes without crashing
      return current;
    }
  }

  TelemetryData _processFrame(TvsFrame frame, TelemetryData current) {
    final payload = frame.plainPayload;

    // TPMS Frame (Start Byte 0x5F)
    if (frame.startByte == 0x5F && payload.length >= 5) {
      final isRear = payload[0] == 0x01;
      final rawPressure = ((payload[1] << 8) | payload[2]) / 10.0;
      final tempC = payload[3];
      final battery = payload[4];

      if (isRear) {
        return current.copyWith(
          rearTyrePsi: rawPressure > 0 ? rawPressure : current.rearTyrePsi,
          rearTyreTempC: tempC,
          rearTyreBattery: battery,
          timestamp: DateTime.now(),
        );
      } else {
        return current.copyWith(
          frontTyrePsi: rawPressure > 0 ? rawPressure : current.frontTyrePsi,
          frontTyreTempC: tempC,
          frontTyreBattery: battery,
          timestamp: DateTime.now(),
        );
      }
    }

    // Standard Telemetry Frames (Start Byte 0x5A)
    switch (frame.opcode) {
      case 0x10:
        return _parseFrame5A10(payload, current);
      case 0x11:
        return _parseFrame5A11(payload, current);
      case 0x12:
        return _parseFrame5A12(payload, current);
      case 0x16:
        return _parseFrame5A16(payload, current);
      case 0x18:
        return _parseFrame5A18(payload, current);
      default:
        return current;
    }
  }

  /// Parses Frame 0x5A 0x10 (Speedometer 1: Speed, RPM, Odo, Fuel, 0-60 Time, Handlebar i-Button)
  TelemetryData _parseFrame5A10(Uint8List payload, TelemetryData current) {
    if (payload.length < 14) return current;

    final speed = payload[0].toDouble();
    final rpm = (payload[1] << 8) | payload[2];
    final odo = ((payload[3] << 16) | (payload[4] << 8) | payload[5]).toDouble();
    final topSpeed = payload[6].toDouble();
    final avgSpeed = payload[7].toDouble();
    final instantMileage = payload[8].toDouble();
    final throttle = payload[9];
    final rawByte10 = payload[10];
    final fuelLevel = rawByte10 & 0x7F;
    final isVoiceAssist = (rawByte10 & 0x20) != 0;
    
    // In TVS U399/U400: Byte 11 contains zero-to-sixty timer high bits,
    // and during call/switch events carries callAcceptRejectStatus:
    // 1 = Accept / Short press, 2 = Reject / Cancel / i-Button long press
    final callStatus = (payload[11] == 1 || payload[11] == 2) ? payload[11] : 0;
    final isIButtonPressed = (callStatus == 2 || callStatus == 1 || isVoiceAssist);
    final zeroToSixty = (payload[11] << 8) | payload[12];
    final tripF = payload.length > 13 ? payload[13] / 10.0 : current.tripFMeterKm;

    return current.copyWith(
      speedKmh: speed,
      engineRpm: rpm,
      odometerKm: odo > 0 ? odo : current.odometerKm,
      topSpeedKmh: topSpeed > current.topSpeedKmh ? topSpeed : current.topSpeedKmh,
      averageSpeedKmh: avgSpeed,
      instantMileageKml: instantMileage,
      throttlePercent: throttle.clamp(0, 100),
      fuelLevelPercent: fuelLevel.clamp(0, 100),
      callAcceptRejectStatus: callStatus,
      isVoiceAssistInvoked: isVoiceAssist,
      isIButtonPressed: isIButtonPressed,
      zeroToSixtyMs: zeroToSixty,
      tripFMeterKm: tripF,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Frame 0x5A 0x11 (Speedometer 2: Gear, Temp, Voltage, Ride Mode, Switches)
  TelemetryData _parseFrame5A11(Uint8List payload, TelemetryData current) {
    if (payload.length < 9) return current;

    final gear = payload[0];
    // Engine Temp: raw byte in °C (offset checked in TVS Connect)
    final engineTemp = payload[1].toDouble();
    final voltage = payload[2] > 0 ? payload[2] / 10.0 : current.batteryVoltage;
    final swVersion = payload[3];

    // Ride Mode: 0=Urban, 1=Sport, 2=Rain, 3=Track
    final modeByte = payload[4];
    RideMode mode;
    switch (modeByte) {
      case 0:
        mode = RideMode.urban;
        break;
      case 1:
        mode = RideMode.sport;
        break;
      case 2:
        mode = RideMode.rain;
        break;
      case 3:
        mode = RideMode.track;
        break;
      default:
        mode = current.rideMode;
    }

    // Vehicle State 1 Bitmask (Disassembled from bitAtGivenPosSetOrUnset in TVS Connect):
    // Bit 0: Side stand down
    // Bit 1: Clutch pulled
    // Bit 2: Brake active
    // Bit 3: Electric start switch
    // Bit 4: Engine kill switch
    final stateFlags = payload[5];
    final sideStandDown = (stateFlags & (1 << 0)) != 0;
    final clutchPulled = (stateFlags & (1 << 1)) != 0;
    final brakeActive = (stateFlags & (1 << 2)) != 0;
    final electricStart = (stateFlags & (1 << 3)) != 0;
    final killSwitchActive = (stateFlags & (1 << 4)) != 0;

    // Turn signal lamp status
    final turnFlags = payload[6];
    final leftSignal = (turnFlags & (1 << 0)) != 0;
    final rightSignal = (turnFlags & (1 << 1)) != 0;

    // Diagnostics / ABS MIL blink codes
    final diagByte = payload[7];
    final absMil = diagByte != 0;

    return current.copyWith(
      gear: gear.clamp(0, 6),
      engineTempC: engineTemp,
      batteryVoltage: voltage,
      clusterSoftwareVersion: swVersion,
      rideMode: mode,
      isSideStandDown: sideStandDown,
      isClutchPulled: clutchPulled,
      isBrakeActive: brakeActive,
      isElectricStartActive: electricStart,
      isKillSwitchActive: killSwitchActive,
      isTurnSignalLeft: leftSignal,
      isTurnSignalRight: rightSignal,
      isAbsMilActive: absMil,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Frame 0x5A 0x12 (Speedometer 3: Lean Angle, G-Force, DTE, Trip Distance)
  TelemetryData _parseFrame5A12(Uint8List payload, TelemetryData current) {
    if (payload.length < 9) return current;

    // Lean angle: signed byte or offset (positive = right, negative = left)
    final rawAngle = payload[0];
    final leanAngle = rawAngle > 127 ? rawAngle - 256 : rawAngle;

    // Acceleration / G-Force (raw / 100.0)
    final accelG = payload[1] / 100.0;

    // Cruising Range / Distance to Empty (DTE) in km
    final dte = (payload[2] << 8) | payload[3];

    // Instant Torque (Nm)
    final torque = payload[4].toDouble();

    // Trip distance (0.1 km increments)
    final tripDist = ((payload[5] << 8) | payload[6]) / 10.0;

    // Trip duration (minutes)
    final tripHours = payload[7];
    final tripMins = payload[8];
    final duration = Duration(hours: tripHours, minutes: tripMins);

    return current.copyWith(
      leanAngleDegrees: leanAngle,
      accelerationG: accelG,
      distanceToEmptyKm: dte,
      instantTorqueNm: torque,
      tripDistanceKm: tripDist,
      tripDuration: duration,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Frame 0x5A 0x16 (Speedometer 4: Lap Trigger & Lap Times)
  TelemetryData _parseFrame5A16(Uint8List payload, TelemetryData current) {
    if (payload.length < 9) return current;

    final lapTrigger = payload[0] == 0x01;
    final lapNum = payload[1];
    final lapMin = payload[2];
    final lapSec = payload[3];
    final lapMs = payload[4] * 10;
    final lapDuration = Duration(minutes: lapMin, seconds: lapSec, milliseconds: lapMs);

    final bestLapNum = payload[5];
    final bestMin = payload[6];
    final bestSec = payload[7];
    final bestMs = payload[8] * 10;
    final bestDuration = Duration(minutes: bestMin, seconds: bestSec, milliseconds: bestMs);

    return current.copyWith(
      isLapTriggered: lapTrigger,
      currentLapNumber: lapNum,
      currentLapTime: lapDuration,
      bestLapNumber: bestLapNum,
      bestLapTime: bestDuration,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Frame 0x5A 0x18 (Speedometer 5: Engine Diagnostics)
  TelemetryData _parseFrame5A18(Uint8List payload, TelemetryData current) {
    if (payload.length < 6) return current;

    final intakeAirTemp = payload[0] - 40; // Standard OBD/CAN temp offset
    final manifoldPressure = ((payload[1] << 8) | payload[2]) / 1000.0;
    final runTimeSec = (payload[3] << 16) | (payload[4] << 8) | payload[5];

    return current.copyWith(
      intakeAirTempC: intakeAirTemp,
      manifoldPressureBar: manifoldPressure,
      engineRunTime: Duration(seconds: runTimeSec),
      timestamp: DateTime.now(),
    );
  }

  @override
  Uint8List buildNavigationPacket(NavigationInstruction instruction) {
    return TvsPacketBuilder.buildNavigationPacket(
      maneuverCode: instruction.maneuver.rtr200LcdGlyphCode,
      distanceMeters: instruction.distanceMeters,
      streetName: instruction.streetName,
      maxStreetLength: maxStreetLength,
    );
  }

  @override
  Uint8List buildTextPacket(String text, {int line = 1}) {
    return TvsPacketBuilder.buildTextPacket(
      text,
      line: line,
      maxLength: maxStreetLength,
    );
  }

  @override
  Uint8List buildPhoneStatePacket({
    required int batteryPercent,
    required int signalStrengthBars,
    bool hasIncomingCall = false,
    bool hasMissedCall = false,
    bool hasSms = false,
  }) {
    return TvsPacketBuilder.buildPhoneStatePacket(
      batteryPercent: batteryPercent,
      signalStrengthBars: signalStrengthBars,
      hasIncomingCall: hasIncomingCall,
      hasMissedCall: hasMissedCall,
      hasSms: hasSms,
    );
  }
}
