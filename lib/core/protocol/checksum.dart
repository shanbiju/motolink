import 'dart:typed_data';

/// TVS SmartXonnect Frame Checksum Algorithm
///
/// Disassembled from `BluetoothUtil.addChecksum` and `isValidChecksum`:
/// Checksum is calculated over the frame bytes prior to the checksum byte.
/// Formula: `checksum = 0xFF - (sum(bytes) & 0xFF)`
/// Verification: `(sum(bytes) + checksum) & 0xFF == 0xFF`
class TvsChecksum {
  TvsChecksum._();

  /// Calculates the TVS 1-byte checksum for the provided byte buffer.
  static int compute(List<int> bytes) {
    if (bytes.isEmpty) return 0xFF;
    var sum = 0;
    for (final b in bytes) {
      sum += (b & 0xFF);
    }
    return (0xFF - (sum & 0xFF)) & 0xFF;
  }

  /// Verifies if a given byte sequence has a valid checksum byte at [checksumIndex].
  static bool verify(List<int> bytes, int checksumIndex) {
    if (checksumIndex < 0 || checksumIndex >= bytes.length) return false;
    final payload = bytes.sublist(0, checksumIndex);
    final expected = compute(payload);
    return (bytes[checksumIndex] & 0xFF) == expected;
  }

  /// Checks if the entire packet up to and including the checksum byte sums to 0xFF.
  static bool verifyCompleteSequence(List<int> bytesWithChecksum) {
    if (bytesWithChecksum.isEmpty) return false;
    var sum = 0;
    for (final b in bytesWithChecksum) {
      sum += (b & 0xFF);
    }
    return (sum & 0xFF) == 0xFF;
  }

  /// Appends the computed checksum and the 0xFF trailer byte to [headerAndPayload].
  /// Result structure: `[...headerAndPayload, checksum, 0xFF]`
  static Uint8List appendChecksumAndTrailer(List<int> headerAndPayload) {
    final checksum = compute(headerAndPayload);
    final result = Uint8List(headerAndPayload.length + 2);
    result.setRange(0, headerAndPayload.length, headerAndPayload);
    result[headerAndPayload.length] = checksum;
    result[headerAndPayload.length + 1] = 0xFF; // Frame end delimiter
    return result;
  }
}
