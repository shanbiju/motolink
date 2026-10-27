import 'dart:typed_data';
import '../features/navigation/navigation_models.dart';
import '../features/telemetry/telemetry_models.dart';

/// Abstract Hardware Abstraction Layer (HAL) for SmartXonnect Motorcycles.
abstract class VehicleAdapter {
  /// Friendly display name for motorcycle model (e.g. "TVS Apache RTR 200 4V")
  String get modelName;

  /// Internal platform code (e.g. "U399" / "U400" / "N597")
  String get platformCode;

  /// BLE Advertising Name prefixes to filter during scan
  List<String> get advertisedNamePrefixes;

  /// Primary GATT Service UUID
  String get serviceUuid;

  /// Read / Notification Characteristic UUID
  String get readCharacteristicUuid;

  /// Write Characteristic UUID
  String get writeCharacteristicUuid;

  /// Maximum street length allowed by cluster hardware
  int get maxStreetLength;

  /// True if motorcycle uses segmented LCD, false if full TFT
  bool get isSegmentedLcd;

  /// Parses raw incoming BLE notification byte stream into updated [TelemetryData].
  TelemetryData parseTelemetry(Uint8List rawBytes, TelemetryData current);

  /// Serializes a navigation instruction into an outgoing BLE command packet.
  Uint8List buildNavigationPacket(NavigationInstruction instruction);

  /// Serializes custom text line (e.g. caller ID or ETA) for the cluster display.
  Uint8List buildTextPacket(String text, {int line = 1});

  /// Serializes mobile device status (battery & cellular signal).
  Uint8List buildPhoneStatePacket({
    required int batteryPercent,
    required int signalStrengthBars,
    bool hasIncomingCall = false,
    bool hasMissedCall = false,
    bool hasSms = false,
  });

  /// Builds the Rider Name handshake packet that wakes the cluster.
  /// This MUST be written to the command characteristic immediately after
  /// GATT service discovery to activate the cluster's Bluetooth session.
  Uint8List buildRiderNamePacket(String riderName);
}
