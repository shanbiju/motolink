import 'dart:convert';
import 'dart:typed_data';
import '../core/protocol/packet_builder.dart';
import '../features/navigation/navigation_models.dart';
import '../features/telemetry/telemetry_models.dart';
import 'tvs_rtr200_adapter.dart';
import 'vehicle_adapter.dart';

/// Concrete Hardware Adapter for TVS Apache RR 310 / RTR 310 (N597 TFT Cluster).
class TvsRr310Adapter implements VehicleAdapter {

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

  final TvsRtr200Adapter _telemetryDecoder = TvsRtr200Adapter();

  @override
  TelemetryData parseTelemetry(Uint8List rawBytes, TelemetryData current) {
    // TVS RR 310 / RTR 310 uses the unified TVS Apache cluster protocol
    return _telemetryDecoder.parseTelemetry(rawBytes, current);
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

  @override
  Uint8List buildRiderNamePacket(String riderName) {
    return TvsPacketBuilder.buildRiderNamePacket(riderName);
  }
}
