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

  /// Parses Frame 0x5A 0x10 (Speedometer 1: Speed, Odo, Fuel, AvgSpeed, Mileage, TopSpeed, Throttle, i-Button, 0-60, TripF, RPM)
  TelemetryData _parseFrame5A10(Uint8List payload, TelemetryData current) {
    if (payload.length < 16) return current;

    // Ground truth from Lcom/tvs/bike/core/protocol/apache/ApacheSpeedOMeter1 & U399SpeedMeter1:
    // payload[0]    (start 3): speed
    // payload[1..3] (start 4, len 3): odometer (24-bit Big-Endian)
    // payload[4]    (start 7): fuelLevel (0-100 or 7-bit)
    // payload[5]    (start 8): averageSpeed
    // payload[6]    (start 9): mileage / economyStatus
    // payload[7]    (start 10): topSpeed
    // payload[8]    (start 11): throttle
    // payload[9]    (start 12): locationTag / switchStatus (i-Button & Call accept/reject)
    // payload[10]   (start 13): zeroTo60Time (0.1s increments or raw ms)
    // payload[11]   (start 14): averageMileageDirect
    // payload[12..13] (start 15, len 2): tripFMeter (0.1 km increments)
    // payload[14..15] (start 17, len 2): engineRpm (16-bit Big-Endian)
    final speed = payload[0].toDouble();
    final odo = ((payload[1] << 16) | (payload[2] << 8) | payload[3]).toDouble();
    final fuelLevel = (payload[4] & 0x7F).clamp(0, 100);
    final avgSpeed = payload[5].toDouble();
    final instantMileage = payload[6].toDouble();
    final topSpeed = payload[7].toDouble();
    final throttle = payload[8].clamp(0, 100);

    // Byte 9 contains handlebar switch status & voice assist flag:
    // 1 = Call Accept / Short Press, 2 = Call Reject / Long Press / i-Button
    final switchByte = payload[9];
    final callStatus = (switchByte == 1 || switchByte == 2) ? switchByte : 0;
    final isVoiceAssist = (switchByte & 0x20) != 0;
    final isIButtonPressed = (callStatus == 1 || callStatus == 2 || isVoiceAssist);

    final zeroToSixty = payload[10] * 100; // converted to ms
    final tripF = ((payload[12] << 8) | payload[13]) / 10.0;
    final rpm = (payload[14] << 8) | payload[15];

    return current.copyWith(
      speedKmh: speed,
      odometerKm: odo > 0 ? odo : current.odometerKm,
      fuelLevelPercent: fuelLevel,
      averageSpeedKmh: avgSpeed,
      instantMileageKml: instantMileage,
      topSpeedKmh: topSpeed > current.topSpeedKmh ? topSpeed : current.topSpeedKmh,
      throttlePercent: throttle,
      callAcceptRejectStatus: callStatus,
      isVoiceAssistInvoked: isVoiceAssist,
      isIButtonPressed: isIButtonPressed,
      zeroToSixtyMs: zeroToSixty,
      tripFMeterKm: tripF,
      engineRpm: rpm,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Frame 0x5A 0x11 (Speedometer 2: Vehicle State, Gear, Battery Voltage, Engine Temp, Ride Mode)
  TelemetryData _parseFrame5A11(Uint8List payload, TelemetryData current) {
    if (payload.length < 16) return current;

    // Ground truth from Lcom/tvs/bike/core/protocol/apache/ApacheSpeedOMeter2 & U399SpeedMeter2:
    // payload[0]  (start 3): vehicleDirection2 / fuelSensor
    // payload[1]  (start 4): vehicleState1
    // payload[2]  (start 5): serviceReminder
    // payload[3]  (start 6): gearPosition (0 = N, 1-6 = Gears)
    // payload[4]  (start 7): batteryVoltage (0.1 V increments, e.g. 124 = 12.4V)
    // payload[5]  (start 8): softwareVersion
    // payload[6]  (start 9): milBlinkCode / reserve1
    // payload[7]  (start 10): vehicleModel / reserve2
    // payload[8]  (start 11): vehicleDiagnostics
    // payload[9]  (start 12): reserve3
    // payload[10] (start 13): turnIndicatorStatus (Bit 0: Left, Bit 1: Right)
    // payload[11] (start 14): engineTemperature (Offset 25: raw >= 25 ? raw - 25 : 0)
    // payload[12] (start 15): intakeAirTemperature / screenMatrix
    // payload[13..14] (start 16): vehicleState3 / fuelInjectionTime
    // payload[14] (start 17): absMilBlinkCode
    // payload[15] (start 18): vehicleMode (0 = Urban, 1 = Sport, 2 = Rain, 3 = Track)

    // Vehicle State 1 Bitmask (from ApacheClusterDataReceiver.bitAtGivenPosSetOrUnset):
    final stateFlags = payload[1];
    final sideStandDown = (stateFlags & (1 << 0)) != 0;
    final sideStandSensor = (stateFlags & (1 << 1)) != 0;
    final clutchPulled = (stateFlags & (1 << 2)) != 0;
    final brakeActive = (stateFlags & (1 << 3)) != 0;
    final electricStart = (stateFlags & (1 << 4)) != 0;
    final killSwitchActive = (stateFlags & (1 << 5)) != 0;

    final gear = payload[3].clamp(0, 6);
    final voltage = payload[4] > 0 ? payload[4] / 10.0 : current.batteryVoltage;
    final swVersion = payload[5];

    // Diagnostics / ABS MIL blink codes from payload[6] and payload[14]
    final absMil = payload[6] != 0 || payload[14] != 0;

    // Turn indicator status from payload[10]
    final turnFlags = payload[10];
    final leftSignal = (turnFlags & (1 << 0)) != 0;
    final rightSignal = (turnFlags & (1 << 1)) != 0;

    // Engine temperature from payload[11] with TVS 25-degree offset calibration
    final rawTemp = payload[11];
    final engineTemp = rawTemp >= 25 ? (rawTemp - 25).toDouble() : 0.0;

    // Ride Mode from payload[15]
    final modeByte = payload[15];
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

    return current.copyWith(
      gear: gear,
      batteryVoltage: voltage,
      clusterSoftwareVersion: swVersion,
      engineTempC: engineTemp,
      rideMode: mode,
      isSideStandDown: sideStandDown || sideStandSensor,
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

  /// Parses Frame 0x5A 0x12 (Speedometer 3: Lean Angle, G-Force, DTE, Torque, Trip Distance, Trip Time)
  TelemetryData _parseFrame5A12(Uint8List payload, TelemetryData current) {
    if (payload.length < 13) return current;

    // Ground truth from Lcom/tvs/bike/core/protocol/apache/ApacheSpeedOMeter3 & U399SpeedMeter3:
    // payload[0]    (start 3): leanAngle (signed 8-bit: > 127 ? raw - 256 : raw)
    // payload[1..2] (start 4, len 2): cruisingRange / Distance to Empty (DTE) in km
    // payload[3]    (start 6): wheelAngelOffset
    // payload[4]    (start 7): acceleration / G-Force (raw / 100.0)
    // payload[5]    (start 8): torque (Nm)
    // payload[6..7] (start 9, len 2): tripDistance (0.1 km increments)
    // payload[8]    (start 11): tripTimeHour
    // payload[9]    (start 12): tripTimeMin
    // payload[10]   (start 13): tripMileage
    // payload[11..12] (start 14, len 2): tripFuel (0.1 L increments)
    final rawAngle = payload[0];
    final leanAngle = rawAngle > 127 ? rawAngle - 256 : rawAngle;

    final dte = (payload[1] << 8) | payload[2];
    final accelG = payload[4] / 100.0;
    final torque = payload[5].toDouble();
    final tripDist = ((payload[6] << 8) | payload[7]) / 10.0;

    final tripHours = payload[8];
    final tripMins = payload[9];
    final duration = Duration(hours: tripHours, minutes: tripMins);

    final tripFuel = ((payload[11] << 8) | payload[12]) / 10.0;

    return current.copyWith(
      leanAngleDegrees: leanAngle,
      distanceToEmptyKm: dte,
      accelerationG: accelG,
      instantTorqueNm: torque,
      tripDistanceKm: tripDist,
      tripDuration: duration,
      tripFuelLiters: tripFuel,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Frame 0x5A 0x16 (Speedometer 4: Lap Telemetry & Lap Times)
  TelemetryData _parseFrame5A16(Uint8List payload, TelemetryData current) {
    if (payload.length < 9) return current;

    // Ground truth from Lcom/tvs/bike/core/protocol/apache/ApacheSpeedOMeter4:
    // payload[0] (start 3): lapTimeMin
    // payload[1] (start 4): lapTimeSec
    // payload[2] (start 5): lapTimeMSec
    // payload[3] (start 6): lapNumber
    // payload[4] (start 7): bestLapMin
    // payload[5] (start 8): bestLapSeconds
    // payload[6] (start 9): bestLapMilliSeconds
    // payload[7] (start 10): bestLapNumber
    // payload[8] (start 11): lapTrigger (0x01 = triggered)
    final lapMin = payload[0];
    final lapSec = payload[1];
    final lapMs = payload[2] * 10;
    final lapDuration = Duration(minutes: lapMin, seconds: lapSec, milliseconds: lapMs);

    final lapNum = payload[3];

    final bestMin = payload[4];
    final bestSec = payload[5];
    final bestMs = payload[6] * 10;
    final bestDuration = Duration(minutes: bestMin, seconds: bestSec, milliseconds: bestMs);

    final bestLapNum = payload[7];
    final lapTrigger = payload[8] == 0x01;

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
    if (payload.length < 12) return current;

    // Ground truth from Lcom/tvs/bike/core/protocol/apache/ApacheSpeedOMeter5:
    // payload[0]    (start 3): engineLoad
    // payload[1..2] (start 4, len 2): accumulatedFuelInjectionTime
    // payload[3]    (start 6): manifoldAirPressure (0.01 bar or kPa)
    // payload[4]    (start 7): barometricPressure
    // payload[5]    (start 8): intakeAirTemperature (OBD offset: raw - 40)
    // payload[6]    (start 9): engineTemperature (TVS offset: raw >= 25 ? raw - 25 : 0)
    // payload[7..8] (start 10, len 2): fuelInjectionTime
    // payload[9]    (start 12): batteryVoltage (raw / 10.0)
    // payload[10..11] (start 13, len 2): runTimeSinceEngineStart (seconds)
    final manifoldPressure = payload[3] / 100.0;
    final intakeAirTemp = payload[5] - 40;
    final runTimeSec = (payload[10] << 8) | payload[11];

    return current.copyWith(
      intakeAirTempC: intakeAirTemp,
      manifoldPressureBar: manifoldPressure > 0 ? manifoldPressure : current.manifoldPressureBar,
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

  @override
  Uint8List buildRiderNamePacket(String riderName) {
    return TvsPacketBuilder.buildRiderNamePacket(riderName);
  }
}
