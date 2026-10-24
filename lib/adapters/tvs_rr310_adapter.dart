import 'dart:convert';
import 'dart:typed_data';
import '../core/protocol/frame_parser.dart';
import '../core/protocol/packet_builder.dart';
import '../features/navigation/navigation_models.dart';
import '../features/telemetry/telemetry_models.dart';
import 'vehicle_adapter.dart';

/// Concrete Hardware Adapter for TVS Apache RR 310 / RTR 310 (N597 TFT Cluster).
class TvsRr310Adapter implements VehicleAdapter {
  final TvsFrameParser _frameParser = TvsFrameParser();

  @override
  String get modelName => 'TVS Apache RR 310 (TFT)';

  @override
  String get platformCode => 'N597';

  @override
  List<String> get advertisedNamePrefixes => const [
        'TVS',
        'RR310',
        'RR 310',
        'RTR310',
        'SmartXonnect',
        'Apache',
      ];

  @override
  String get serviceUuid => '5456534D-5647-5341-5342-454E544F5251';

  @override
  String get readCharacteristicUuid => '00005354-0000-1000-8000-00805F9B34FB';

  @override
  String get writeCharacteristicUuid => '00005352-0000-1000-8000-00805F9B34FB';

  @override
  int get maxStreetLength => 32;

  @override
  bool get isSegmentedLcd => false;

  @override
  TelemetryData parseTelemetry(Uint8List rawBytes, TelemetryData current) {
    try {
      final frames = _frameParser.feed(rawBytes);
      var state = current;
      for (final frame in frames) {
        // RR 310 uses identical base telemetry framing with extended widget metadata
        final payload = frame.plainPayload;
        if (frame.opcode == 0x10 && payload.length >= 14) {
          state = state.copyWith(
            speedKmh: payload[0].toDouble(),
            engineRpm: (payload[1] << 8) | payload[2],
            odometerKm: ((payload[3] << 16) | (payload[4] << 8) | payload[5]).toDouble(),
            timestamp: DateTime.now(),
          );
        } else if (frame.opcode == 0x11 && payload.length >= 9) {
          state = state.copyWith(
            gear: payload[0].clamp(0, 6),
            engineTempC: payload[1].toDouble(),
            batteryVoltage: payload[2] / 10.0,
            timestamp: DateTime.now(),
          );
        } else if (frame.opcode == 0x12 && payload.length >= 9) {
          final rawAngle = payload[0];
          state = state.copyWith(
            leanAngleDegrees: rawAngle > 127 ? rawAngle - 256 : rawAngle,
            accelerationG: payload[1] / 100.0,
            distanceToEmptyKm: (payload[2] << 8) | payload[3],
            timestamp: DateTime.now(),
          );
        }
      }
      return state;
    } catch (_) {
      return current;
    }
  }

  @override
  Uint8List buildNavigationPacket(NavigationInstruction instruction) {
    // RR 310 supports extended UTF-8 street names up to 32 chars and numeric pictogram IDs
    final cleanStreet = instruction.streetName.trim();
    final clampedStreet = cleanStreet.length > maxStreetLength
        ? cleanStreet.substring(0, maxStreetLength)
        : cleanStreet;
    final streetBytes = utf8.encode(clampedStreet);

    final payload = <int>[
      instruction.maneuver.index, // Numeric index for TFT icon matrix
      (instruction.distanceMeters >> 8) & 0xFF,
      instruction.distanceMeters & 0xFF,
      instruction.etaMinutes ?? 0,
      ...streetBytes,
    ];

    return TvsPacketBuilder.buildFrame(0x01, payload);
  }

  @override
  Uint8List buildTextPacket(String text, {int line = 1}) {
    final clean = text.trim();
    final clamped = clean.length > maxStreetLength ? clean.substring(0, maxStreetLength) : clean;
    return TvsPacketBuilder.buildFrame(line == 2 ? 0x03 : 0x02, utf8.encode(clamped));
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
