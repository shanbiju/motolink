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
  static const int standardFrameLength = 20;

  final List<int> _buffer = [];

  /// Maximum allowed buffer length to prevent memory exhaustion
  static const int maxBufferLength = 256;

  /// Feeds incoming raw BLE chunk into parser, returning zero or more valid frames.
  List<TvsFrame> feed(Uint8List chunk) {
    _buffer.addAll(chunk);

    // Safeguard against unbounded buffer growth
    if (_buffer.length > maxBufferLength) {
      _buffer.removeRange(0, _buffer.length - standardFrameLength);
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

      // Need at least 4 bytes to determine anything
      if (_buffer.length < 4) {
        break; // Wait for more data
      }

      // In TVS SmartXonnect, packets sent over BLE notify (0x5354) are 20 bytes:
      // [StartByte, Opcode, 16-byte Payload, Checksum, Delimiter/EndByte]
      if (_buffer.length >= standardFrameLength) {
        final candidate = Uint8List.fromList(_buffer.sublist(0, standardFrameLength));
        final checksumByte = candidate[18];

        // Verify checksum at index 18
        if (TvsChecksum.verify(candidate, 18)) {
          final decrypted = TvsCipher.decryptFrame(candidate);
          final plainPayload = decrypted.sublist(2, 18);

          frames.add(TvsFrame(
            startByte: candidate[0],
            opcode: candidate[1],
            plainPayload: plainPayload,
            checksum: checksumByte,
            rawFrame: candidate,
          ));

          _buffer.removeRange(0, standardFrameLength);
          continue;
        }
      }

      // If buffer is 20 bytes or more but failed checksum, check if there is an
      // alternate variable-length delimiter (e.g. 0x0D, 0x0A, 0x5D, 0xFF)
      final altEndIndex = _buffer.indexWhere(
        (b) => b == 0x0D || b == 0x0A || b == 0x5D || b == 0xFF,
        3,
      );

      if (altEndIndex != -1 && altEndIndex < 32) {
        final frameLen = altEndIndex + 1;
        final rawSlice = Uint8List.fromList(_buffer.sublist(0, frameLen));
        final checksumIndex = frameLen - 2;

        if (checksumIndex >= 2 && TvsChecksum.verify(rawSlice, checksumIndex)) {
          final decrypted = TvsCipher.decryptFrame(rawSlice);
          final plainPayload = decrypted.sublist(2, checksumIndex);

          frames.add(TvsFrame(
            startByte: rawSlice[0],
            opcode: rawSlice[1],
            plainPayload: plainPayload,
            checksum: rawSlice[checksumIndex],
            rawFrame: rawSlice,
          ));

          _buffer.removeRange(0, frameLen);
          continue;
        }
      }

      // If we have at least 20 bytes and neither matched, pop the false start byte to resync
      if (_buffer.length >= standardFrameLength) {
        _buffer.removeAt(0);
      } else {
        // Less than 20 bytes, wait for the rest of the BLE packet
        break;
      }
    }

    return frames;
  }

  /// Resets internal buffer state.
  void reset() {
    _buffer.clear();
  }
}
