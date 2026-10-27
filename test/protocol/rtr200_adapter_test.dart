import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/adapters/tvs_rtr200_adapter.dart';
import 'package:motolink/core/protocol/checksum.dart';
import 'package:motolink/core/protocol/cipher.dart';
import 'package:motolink/features/navigation/navigation_models.dart';
import 'package:motolink/features/telemetry/telemetry_models.dart';

void main() {
  group('TvsRtr200Adapter Protocol Tests', () {
    late TvsRtr200Adapter adapter;

    setUp(() {
      adapter = TvsRtr200Adapter();
    });

    Uint8List buildEncryptedFrame(int startByte, int opcode, List<int> plainPayload) {
      final padded = List<int>.filled(16, 0);
      for (int i = 0; i < plainPayload.length && i < 16; i++) {
        padded[i] = plainPayload[i];
      }
      final encryptedPayload = TvsCipher.cryptPayload(padded);
      final rawBeforeChecksum = [startByte, opcode, ...encryptedPayload];
      final checksum = TvsChecksum.compute(rawBeforeChecksum);
      return Uint8List.fromList([...rawBeforeChecksum, checksum, 0x0D]);
    }

    test('Decodes Frame 0x5A 0x10 (Speed, RPM, Odo, Fuel, 0-60)', () {
      // Ground truth layout:
      // Byte 0: Speed (54 km/h)
      // Byte 1-3: Odo = 12500 km (0x0030D4 -> 0x00, 0x30, 0xD4)
      // Byte 4: Fuel Level (85%)
      // Byte 5: Avg Speed (46 km/h)
      // Byte 6: Mileage (38 km/L)
      // Byte 7: Top Speed (118 km/h)
      // Byte 8: Throttle (42%)
      // Byte 9: SwitchStatus (0)
      // Byte 10: 0-60 time = 39 (3900 ms)
      // Byte 11: Direct mileage (0)
      // Byte 12-13: Trip F = 15 (1.5 km)
      // Byte 14-15: RPM = 5800 (0x16A8 -> 0x16, 0xA8)
      final plain = [
        54,
        0x00, 0x30, 0xD4,
        85,
        46,
        38,
        118,
        42,
        0,
        39,
        0,
        0x00, 15,
        0x16, 0xA8,
      ];

      final rawPacket = buildEncryptedFrame(0x5A, 0x10, plain);
      final initial = TelemetryData.initial();
      final updated = adapter.parseTelemetry(rawPacket, initial);

      expect(updated.speedKmh, equals(54.0));
      expect(updated.engineRpm, equals(5800));
      expect(updated.odometerKm, equals(12500.0));
      expect(updated.topSpeedKmh, equals(118.0));
      expect(updated.averageSpeedKmh, equals(46.0));
      expect(updated.instantMileageKml, equals(38.0));
      expect(updated.throttlePercent, equals(42));
      expect(updated.fuelLevelPercent, equals(85));
      expect(updated.zeroToSixtyMs, equals(3900));
      expect(updated.tripFMeterKm, equals(1.5));
    });

    test('Decodes Frame 0x5A 0x11 (Gear, Temp, Battery, Mode, Switches Bitmask)', () {
      // Ground truth layout:
      // Byte 0: vehicleDirection2 = 0
      // Byte 1: StateFlags (Bit 0: SideStand=1, Bit 2: Clutch=1, Bit 5: Kill=1) = 0x25
      // Byte 2: serviceReminder = 0
      // Byte 3: Gear = 4
      // Byte 4: Battery = 142 (14.2V)
      // Byte 5: SwVersion = 2
      // Byte 6: Diag / ABS MIL = 1
      // Byte 7-9: 0
      // Byte 10: TurnFlags (Bit 0: Left=1) = 0x01
      // Byte 11: Temp = 107 (107 - 25 = 82°C)
      // Byte 12-14: 0
      // Byte 15: RideMode = 1 (Sport)
      const stateFlags = (1 << 0) | (1 << 2) | (1 << 5); // Side stand, Clutch, Kill switch
      const turnFlags = (1 << 0); // Left turn
      final plain = [
        0,
        stateFlags,
        0,
        4,
        142,
        2,
        1, // Diag
        0, 0, 0,
        turnFlags,
        107, // 107 - 25 = 82 C
        0, 0, 0,
        1, // Sport
      ];

      final rawPacket = buildEncryptedFrame(0x5A, 0x11, plain);
      final initial = TelemetryData.initial();
      final updated = adapter.parseTelemetry(rawPacket, initial);

      expect(updated.gear, equals(4));
      expect(updated.engineTempC, equals(82.0));
      expect(updated.batteryVoltage, closeTo(14.2, 0.01));
      expect(updated.rideMode, equals(RideMode.sport));
      expect(updated.isSideStandDown, isTrue);
      expect(updated.isClutchPulled, isTrue);
      expect(updated.isBrakeActive, isFalse);
      expect(updated.isKillSwitchActive, isTrue);
      expect(updated.isTurnSignalLeft, isTrue);
      expect(updated.isTurnSignalRight, isFalse);
      expect(updated.isAbsMilActive, isTrue);
    });

    test('Decodes Frame 0x5A 0x12 (Lean Angle, G-Force, DTE, Trip Distance)', () {
      // Ground truth layout:
      // Byte 0: Lean Angle = -24° (Left lean: 256 - 24 = 232 = 0xE8)
      // Byte 1-2: DTE = 195 km (0x00C3 -> 0x00, 0xC3)
      // Byte 3: WheelAngleOffset = 0
      // Byte 4: Acceleration G = 65 (0.65 G)
      // Byte 5: Instant Torque = 16 Nm
      // Byte 6-7: Trip Distance = 28.5 km (285 -> 0x011D -> 0x01, 0x1D)
      // Byte 8: Trip Hours = 1
      // Byte 9: Trip Mins = 12
      // Byte 10: Trip Mileage = 0
      // Byte 11-12: Trip Fuel = 0
      final plain = [
        0xE8, // -24 signed
        0x00, 0xC3,
        0,
        65,   // 0.65 G
        16,
        0x01, 0x1D,
        1, 12,
        0,
        0, 0,
      ];

      final rawPacket = buildEncryptedFrame(0x5A, 0x12, plain);
      final initial = TelemetryData.initial();
      final updated = adapter.parseTelemetry(rawPacket, initial);

      expect(updated.leanAngleDegrees, equals(-24));
      expect(updated.accelerationG, closeTo(0.65, 0.01));
      expect(updated.distanceToEmptyKm, equals(195));
      expect(updated.instantTorqueNm, equals(16.0));
      expect(updated.tripDistanceKm, closeTo(28.5, 0.01));
      expect(updated.tripDuration.inHours, equals(1));
      expect(updated.tripDuration.inMinutes % 60, equals(12));
    });

    test('Decodes Frame 0x5F (TPMS Rear and Front Sensors)', () {
      // Rear tyre: pos=1, pressure=360 (36.0 PSI), temp=34°C, bat=90%
      final plainRear = [
        1,
        0x01, 0x68, // 360
        34,
        90,
      ];

      final rawRear = buildEncryptedFrame(0x5F, 0x01, plainRear);
      final initial = TelemetryData.initial();
      final updatedRear = adapter.parseTelemetry(rawRear, initial);

      expect(updatedRear.rearTyrePsi, closeTo(36.0, 0.1));
      expect(updatedRear.rearTyreTempC, equals(34));
      expect(updatedRear.rearTyreBattery, equals(90));
    });

    test('Serializes turn-by-turn navigation packet with LCD 15-char clamping and pictogram code', () {
      const instruction = NavigationInstruction(
        maneuver: ManeuverType.turnRight, // 'B' (0x42)
        distanceMeters: 450,
        streetName: 'Mahatma Gandhi Road Bangalore',
      );

      final packet = adapter.buildNavigationPacket(instruction);

      // Verify framing: Start byte 0x5B, End byte 0xFF
      expect(packet[0], equals(0x5B));
      expect(packet[1], equals(0x01)); // Navigation opcode
      expect(packet[packet.length - 1], equals(0xFF));

      // Verify checksum
      final checksumValid = TvsChecksum.verify(packet, packet.length - 2);
      expect(checksumValid, isTrue);

      // Decrypt frame and verify inner payload
      final decrypted = TvsCipher.decryptFrame(packet);
      expect(decrypted[2], equals(0x42)); // 'B'
      expect((decrypted[3] << 8) | decrypted[4], equals(450));

      // Street name must be clamped to 15 chars: "MAHATMA GANDHI "
      final streetSlice = decrypted.sublist(5, decrypted.length - 2);
      final streetStr = String.fromCharCodes(streetSlice);
      expect(streetStr.length, equals(15));
      expect(streetStr, equals('MAHATMA GANDHI '));
    });

    test('Handles malformed or truncated packets gracefully without crashing', () {
      final initial = TelemetryData.initial();

      // Empty bytes
      expect(adapter.parseTelemetry(Uint8List(0), initial), equals(initial));

      // Truncated frame
      final truncated = Uint8List.fromList([0x5A, 0x10, 0x22]);
      expect(adapter.parseTelemetry(truncated, initial), equals(initial));

      // Invalid start byte
      final invalidStart = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]);
      expect(adapter.parseTelemetry(invalidStart, initial), equals(initial));
    });
  });
}
