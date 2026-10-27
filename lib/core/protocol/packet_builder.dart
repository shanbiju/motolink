import 'dart:convert';
import 'dart:typed_data';
import 'checksum.dart';
import 'cipher.dart';

/// Helper to build TVS SmartXonnect compliant outgoing packets (Mobile -> Cluster).
class TvsPacketBuilder {
  TvsPacketBuilder._();

  static const int headerApp = 0x5B; // '['

  /// Sanitizes text for TVS segmented LCD screens:
  /// - Strips diacritics / emojis / non-ASCII characters
  /// - Converts to uppercase
  /// - Clamps length to [maxLength] (defaults to 15 chars for RTR 200 4V)
  /// - Pads with trailing spaces if needed
  static String sanitizeForLcd(String input, {int maxLength = 15}) {
    if (input.isEmpty) return ' ' * maxLength;

    // Disassemble inspection of BluetoothUtil.createNavigationAssistArray revealed:
    // Regex regex = new Regex("[\\p{So}\\p{Cn}\\x{1F300}-\\x{1F6FF}\\x{1F900}-\\x{1F9FF}\\x{1FA70}-\\x{1FAFF}\\x{2600}-\\x{26FF}\\u200D]");
    // Non-ASCII replaced or filtered to ASCII alphanumeric + space.
    final buffer = StringBuffer();
    final upper = input.toUpperCase();

    for (var i = 0; i < upper.length; i++) {
      final code = upper.codeUnitAt(i);
      // 'A'-'Z' (65-90), '0'-'9' (48-57), ' ' (32), '-' (45), '.' (46)
      if ((code >= 65 && code <= 90) ||
          (code >= 48 && code <= 57) ||
          code == 32 ||
          code == 45 ||
          code == 46) {
        buffer.writeCharCode(code);
      } else {
        buffer.write(' ');
      }
    }

    var clean = buffer.toString().trim();
    if (clean.length > maxLength) {
      clean = clean.substring(0, maxLength);
    }
    return clean.padRight(maxLength, ' ');
  }

  /// Standard BLE MTU frame size expected by TVS cluster firmware.
  /// All command packets must be padded to exactly this length:
  /// [0x5B, opcode, ...16-byte payload/padding, checksum, 0xFF]
  static const int tvsFrameSize = 20;

  /// Builds a complete encrypted, checksummed frame:
  /// `[0x5B, opcode, ...EncryptedPayload, Checksum, 0xFF]`
  static Uint8List buildFrame(int opcode, List<int> plainPayload) {
    // 1. Assemble raw header + plain payload
    final unencrypted = Uint8List(2 + plainPayload.length);
    unencrypted[0] = headerApp;
    unencrypted[1] = opcode & 0xFF;
    unencrypted.setRange(2, unencrypted.length, plainPayload);

    // 2. Encrypt payload portion using XOR key 0xEA
    final encryptedHeaderAndPayload = TvsCipher.encryptPayloadInPlace(unencrypted);

    // 3. Append checksum and 0xFF end delimiter
    return TvsChecksum.appendChecksumAndTrailer(encryptedHeaderAndPayload);
  }

  /// Builds a fixed-size 20-byte encrypted, checksummed frame.
  /// The TVS cluster firmware expects all command writes to characteristic
  /// 0x5352 to be exactly 20 bytes. Payloads shorter than 16 bytes are
  /// zero-padded; payloads longer are truncated.
  /// Result: `[0x5B, opcode, ...16 encrypted bytes, checksum, 0xFF]`
  static Uint8List buildFrame20(int opcode, List<int> plainPayload) {
    // Fixed payload area = tvsFrameSize - 4 (header byte, opcode, checksum, trailer)
    const payloadSlotSize = tvsFrameSize - 4; // 16 bytes

    // 1. Pad or truncate payload to exactly payloadSlotSize
    final paddedPayload = List<int>.filled(payloadSlotSize, 0);
    final copyLen = plainPayload.length < payloadSlotSize
        ? plainPayload.length
        : payloadSlotSize;
    for (var i = 0; i < copyLen; i++) {
      paddedPayload[i] = plainPayload[i] & 0xFF;
    }

    return buildFrame(opcode, paddedPayload);
  }

  /// Builds a Turn-by-Turn navigation instruction packet (Opcode 0x01).
  ///
  /// [maneuverCode]: ASCII pictogram character, e.g. 'A' (Straight), 'B' (Right), 'C' (Left).
  /// [distanceMeters]: Distance to maneuver in meters (0 - 65535).
  /// [streetName]: Street name string, sanitized and clamped to [maxStreetLength] (15 for LCD).
  static Uint8List buildNavigationPacket({
    required int maneuverCode,
    required int distanceMeters,
    required String streetName,
    int maxStreetLength = 15,
  }) {
    final sanitizedStreet = sanitizeForLcd(streetName, maxLength: maxStreetLength);
    final streetBytes = ascii.encode(sanitizedStreet);

    final payload = <int>[];
    // Byte 0: Maneuver pictogram code
    payload.add(maneuverCode & 0xFF);
    // Bytes 1-2: Distance in meters (big-endian 16-bit)
    payload.add((distanceMeters >> 8) & 0xFF);
    payload.add(distanceMeters & 0xFF);
    // Bytes 3+: Street name bytes
    payload.addAll(streetBytes);

    return buildFrame(0x01, payload);
  }

  /// Builds a custom text line packet (Opcode 0x02 for Line 1, 0x03 for Line 2).
  static Uint8List buildTextPacket(String text, {int line = 1, int maxLength = 15}) {
    final opcode = (line == 2) ? 0x03 : 0x02;
    final sanitized = sanitizeForLcd(text, maxLength: maxLength);
    final textBytes = ascii.encode(sanitized);
    return buildFrame(opcode, textBytes);
  }

  /// Builds a phone status packet (Opcode 0x4A / 'J').
  ///
  /// Disassembled from `BlePacketsProvider.sendApacheMobileData`:
  /// The cluster firmware expects opcode 0x4A with the phone battery,
  /// network signal bars, and notification flags packed into a 20-byte frame.
  /// The old opcode 0x05 was silently discarded by the cluster firmware.
  static Uint8List buildPhoneStatePacket({
    required int batteryPercent,
    required int signalStrengthBars, // 0 to 5 bars
    bool hasIncomingCall = false,
    bool hasMissedCall = false,
    bool hasSms = false,
  }) {
    var flags = 0;
    if (hasIncomingCall) flags |= 0x01;
    if (hasMissedCall) flags |= 0x02;
    if (hasSms) flags |= 0x04;

    final payload = <int>[
      batteryPercent.clamp(0, 100),
      signalStrengthBars.clamp(0, 5),
      flags,
    ];

    return buildFrame20(0x4A, payload);
  }

  /// Builds the Rider Name handshake packet (Opcode 0x52 / 'R').
  ///
  /// Disassembled from `BluetoothUtil.createRiderNameArray`:
  /// This is the **critical connection handshake**. When the cluster receives
  /// `[0x5B, 0x52, ...riderNameBytes..., padding, checksum, 0xFF]`,
  /// it activates the Bluetooth icon on the speedometer LCD, displays
  /// "HELLO RIDER", and begins streaming live 10 Hz telemetry frames.
  ///
  /// Without this packet, the cluster remains dormant despite a valid
  /// BLE GATT connection — the app shows "Connected" but the bike
  /// doesn't know a session has started.
  ///
  /// Frame structure (20 bytes total):
  /// [0x5B, 0x52, riderName[0..16], padding, checksum, 0xFF]
  static Uint8List buildRiderNamePacket(String riderName) {
    // Sanitize: the cluster LCD only supports ASCII alphanumeric + space
    final sanitized = sanitizeForLcd(riderName, maxLength: 14);
    final nameBytes = ascii.encode(sanitized);

    // Payload: rider name bytes (up to 14 chars, zero-padded to 16 slots)
    final payload = <int>[...nameBytes];

    return buildFrame20(0x52, payload);
  }
}
