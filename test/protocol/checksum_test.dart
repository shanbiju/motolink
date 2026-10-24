import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/core/protocol/checksum.dart';

void main() {
  group('TvsChecksum Protocol Tests', () {
    test('Calculates valid checksum for basic packet sequence', () {
      // Sample packet: [0x5A, 0x10, 0x30, 0x15]
      // Sum = 90 + 16 + 48 + 21 = 175 (0xAF)
      // Checksum = 0xFF - 0xAF = 0x50 (80)
      final bytes = [0x5A, 0x10, 0x30, 0x15];
      final checksum = TvsChecksum.compute(bytes);
      expect(checksum, equals(0x50));
      expect((175 + checksum) & 0xFF, equals(0xFF));
    });

    test('Verifies checksum correctly in complete sequence', () {
      final bytes = [0x5A, 0x10, 0x30, 0x15];
      final packetWithChecksum = TvsChecksum.appendChecksumAndTrailer(bytes);

      // Structure: [0x5A, 0x10, 0x30, 0x15, 0x50, 0xFF]
      expect(packetWithChecksum.length, equals(6));
      expect(packetWithChecksum[4], equals(0x50));
      expect(packetWithChecksum[5], equals(0xFF));

      // Verify complete sequence up to checksum
      final isValid = TvsChecksum.verify(packetWithChecksum, 4);
      expect(isValid, isTrue);

      final isSumValid = TvsChecksum.verifyCompleteSequence(
        packetWithChecksum.sublist(0, 5),
      );
      expect(isSumValid, isTrue);
    });

    test('Detects corrupted checksum byte', () {
      final corruptedPacket = [0x5A, 0x10, 0x30, 0x15, 0x51, 0xFF];
      final isValid = TvsChecksum.verify(corruptedPacket, 4);
      expect(isValid, isFalse);
    });

    test('Handles empty and single byte edge cases safely', () {
      expect(TvsChecksum.compute([]), equals(0xFF));
      expect(TvsChecksum.compute([0x00]), equals(0xFF));
      expect(TvsChecksum.compute([0xFF]), equals(0x00));
    });
  });
}
