import 'dart:typed_data';

/// TVS SmartXonnect Application-Level XOR Stream Cipher
///
/// Disassembled from `BluetoothUtil.getKeyByteArrayApache`, `encryptDataApache`,
/// and `decryptDataForApache`.
///
/// The payload between the 2-byte header `[StartByte, Opcode]` and the 2-byte footer
/// `[Checksum, 0xFF]` is encrypted using a symmetric byte-wise XOR against
/// key constant `0xEA` (-22 signed).
class TvsCipher {
  TvsCipher._();

  /// Key byte used for Apache RTR 200 / TVS SmartXonnect frame encryption.
  /// Bytecode reveals signed byte `-22`, which is `0xEA` in unsigned 8-bit.
  static const int xorKey = 0xEA;

  /// Symmetric XOR encryption / decryption on an isolated payload slice.
  static Uint8List cryptPayload(List<int> payload) {
    final result = Uint8List(payload.length);
    for (var i = 0; i < payload.length; i++) {
      result[i] = (payload[i] ^ xorKey) & 0xFF;
    }
    return result;
  }

  /// Decrypts a full received frame `[StartByte, Opcode, ...EncryptedPayload, Checksum, 0xFF]`.
  /// Returns a new Uint8List where bytes from index 2 to `length - 3` are decrypted.
  /// If the packet is shorter than 4 bytes, returns the input untouched.
  static Uint8List decryptFrame(Uint8List frame) {
    if (frame.length < 4) {
      return Uint8List.fromList(frame);
    }
    final result = Uint8List.fromList(frame);
    // Payload starts after header (2 bytes) and ends before checksum (1 byte) + footer (1 byte)
    final payloadEnd = frame.length - 2;
    for (var i = 2; i < payloadEnd; i++) {
      result[i] = (frame[i] ^ xorKey) & 0xFF;
    }
    return result;
  }

  /// Encrypts an outgoing frame `[StartByte, Opcode, ...PlainPayload]`.
  /// Applies XOR cipher to `[2..length]`.
  static Uint8List encryptPayloadInPlace(List<int> headerAndPayload) {
    if (headerAndPayload.length <= 2) {
      return Uint8List.fromList(headerAndPayload);
    }
    final result = Uint8List.fromList(headerAndPayload);
    for (var i = 2; i < result.length; i++) {
      result[i] = (result[i] ^ xorKey) & 0xFF;
    }
    return result;
  }
}
