import 'dart:typed_data';
import 'checksum.dart';
import 'cipher.dart';

/// Represents a parsed TVS BLE Protocol Frame
class TvsFrame {
  final int startByte;
  final int opcode;
  final Uint8List plainPayload;
  final int checksum;
  final Uint8List rawFrame;

  const TvsFrame({
    required this.startByte,
    required this.opcode,
    required this.plainPayload,
    required this.checksum,
    required this.rawFrame,
  });

  bool get isClusterToApp => startByte == 0x5A || startByte == 0x5F;
  bool get isAppToCluster => startByte == 0x5B;

  @override
  String toString() =>
      'TvsFrame(start: 0x${startByte.toRadixString(16).padLeft(2, '0')}, '
      'op: 0x${opcode.toRadixString(16).padLeft(2, '0')}, '
      'payloadLen: ${plainPayload.length}, '
      'chk: 0x${checksum.toRadixString(16).padLeft(2, '0')})';
}

/// Robust stream buffer and framer for TVS SmartXonnect packets.
class TvsFrameParser {
  static const int headerCluster = 0x5A; // 'Z'
  static const int headerMobile = 0x5B;  // '['
  static const int headerTpms = 0x5F;    // '_'
  static const int frameEnd = 0xFF;

  final List<int> _buffer = [];

  /// Maximum allowed frame length to prevent buffer exhaustion from malformed packets
  static const int maxFrameLength = 256;

  /// Feeds incoming raw BLE chunk into parser, returning zero or more valid frames.
  List<TvsFrame> feed(Uint8List chunk) {
    _buffer.addAll(chunk);

    // Safeguard against unbounded buffer growth if noise or missing 0xFF
    if (_buffer.length > maxFrameLength * 4) {
      _buffer.removeRange(0, _buffer.length - maxFrameLength);
    }

    final frames = <TvsFrame>[];

    while (_buffer.isNotEmpty) {
      // Find candidate start byte
      final startIndex = _buffer.indexWhere(
        (b) => b == headerCluster || b == headerMobile || b == headerTpms,
      );

      if (startIndex == -1) {
        _buffer.clear();
        break;
      }

      if (startIndex > 0) {
        // Discard unaligned bytes before start byte
        _buffer.removeRange(0, startIndex);
      }

      // Need at least [StartByte, Opcode, Checksum, 0xFF] = 4 bytes
      if (_buffer.length < 4) {
        break; // Wait for more data
      }

      // Find frame terminator 0xFF after start byte
      final endIndex = _buffer.indexOf(frameEnd, 2);
      if (endIndex == -1) {
        if (_buffer.length > maxFrameLength) {
          // Packet exceeded max length without delimiter, discard first byte to resync
          _buffer.removeAt(0);
          continue;
        }
        break; // Incomplete packet, wait for next BLE chunk
      }

      final frameLength = endIndex + 1;
      final rawSlice = Uint8List.fromList(_buffer.sublist(0, frameLength));

      // Checksum is at endIndex - 1
      final checksumIndex = endIndex - 1;
      final checksumByte = rawSlice[checksumIndex];

      // Verify checksum across payload prior to checksum byte
      final isValid = TvsChecksum.verify(rawSlice, checksumIndex);
      if (!isValid) {
        // Corrupted packet or false start byte, pop start byte and retry
        _buffer.removeAt(0);
        continue;
      }

      // Valid frame detected! Decrypt payload
      final decrypted = TvsCipher.decryptFrame(rawSlice);
      final plainPayload = decrypted.sublist(2, checksumIndex);

      frames.add(TvsFrame(
        startByte: rawSlice[0],
        opcode: rawSlice[1],
        plainPayload: plainPayload,
        checksum: checksumByte,
        rawFrame: rawSlice,
      ));

      // Remove processed frame from buffer
      _buffer.removeRange(0, frameLength);
    }

    return frames;
  }

  /// Resets internal buffer state.
  void reset() {
    _buffer.clear();
  }
}
