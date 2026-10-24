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
      final encryptedPayload = TvsCipher.cryptPayload(plainPayload);
      final rawBeforeChecksum = [startByte, opcode, ...encryptedPayload];
      final checksum = TvsChecksum.compute(rawBeforeChecksum);
      return Uint8List.fromList([...rawBeforeChecksum, checksum, 0xFF]);
    }

    test('Decodes Frame 0x5A 0x10 (Speed, RPM, Odo, Fuel, 0-60)', () {
      // Plain Payload layout:
      // Byte 0: Speed (54 km/h)
      // Byte 1-2: RPM = 5800 (0x16A8 -> 0x16, 0xA8)
      // Byte 3-5: Odo = 12500 km (0x0030D4 -> 0x00, 0x30, 0xD4)
      // Byte 6: Top Speed (118 km/h)
      // Byte 7: Avg Speed (46 km/h)
      // Byte 8: Mileage (38 km/L)
      // Byte 9: Throttle (42%)
      // Byte 10: Fuel Level (85%)
      // Byte 11-12: 0-60 time = 3950 ms (0x0F6E -> 0x0F, 0x6E)
      // Byte 13: Trip F = 15 (1.5 km)
      final plain = [
        54,
        0x16, 0xA8,
        0x00, 0x30, 0xD4,
        118,
        46,
        38,
        42,
        85,
        0x0F, 0x6E,
        15,
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
      expect(updated.zeroToSixtyMs, equals(3950));
      expect(updated.tripFMeterKm, equals(1.5));
    });

    test('Decodes Frame 0x5A 0x11 (Gear, Temp, Battery, Mode, Switches Bitmask)', () {
      // Plain Payload layout:
      // Byte 0: Gear = 4
      // Byte 1: Temp = 82°C
      // Byte 2: Battery = 142 (14.2V)
      // Byte 3: SwVersion = 2
      // Byte 4: RideMode = 1 (Sport)
      // Byte 5: StateFlags (Bit 0: SideStand=1, Bit 1: Clutch=1, Bit 2: Brake=0, Bit 3: Start=0, Bit 4: Kill=1)
      //         0x01 | 0x02 | 0x10 = 0x13
      // Byte 6: TurnFlags (Bit 0: Left=1, Bit 1: Right=0) = 0x01
      // Byte 7: Diag = 1 (ABS MIL active)
      // Byte 8: Reserved = 0
      const stateFlags = (1 << 0) | (1 << 1) | (1 << 4); // Side stand, Clutch, Kill switch
      const turnFlags = (1 << 0); // Left turn
      final plain = [
        4,
        82,
        142,
        2,
        1, // Sport
        stateFlags,
        turnFlags,
        1, // Diag
        0,
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
      // Byte 0: Lean Angle = -24° (Left lean: 256 - 24 = 232 = 0xE8)
      // Byte 1: Acceleration G = 65 (0.65 G)
      // Byte 2-3: DTE = 195 km (0x00C3 -> 0x00, 0xC3)
      // Byte 4: Instant Torque = 16 Nm
      // Byte 5-6: Trip Distance = 28.5 km (285 -> 0x011D -> 0x01, 0x1D)
      // Byte 7: Trip Hours = 1
      // Byte 8: Trip Mins = 12
      final plain = [
        0xE8, // -24 signed
        65,   // 0.65 G
        0x00, 0xC3,
        16,
        0x01, 0x1D,
        1, 12,
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
