import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/core/protocol/cipher.dart';

void main() {
  group('TvsCipher Protocol Tests', () {
    test('XOR symmetric encryption and decryption with key 0xEA', () {
      final original = Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]);
      final encrypted = TvsCipher.cryptPayload(original);

      // Verify that every byte is XORed with 0xEA
      for (var i = 0; i < original.length; i++) {
        expect(encrypted[i], equals(original[i] ^ 0xEA));
      }

      // Decrypting the encrypted payload must return the original bytes
      final decrypted = TvsCipher.cryptPayload(encrypted);
      expect(decrypted, equals(original));
    });

    test('Frame decryption preserves headers and footers intact', () {
      // Frame: [Header 0x5A, Opcode 0x10, ...PlainPayload, Checksum 0x50, Footer 0xFF]
      final plainPayload = [0x01, 0x02, 0x03];
      final encryptedPayload = TvsCipher.cryptPayload(plainPayload);

      final fullFrame = Uint8List.fromList([
        0x5A,
        0x10,
        ...encryptedPayload,
        0x50,
        0xFF,
      ]);

      final decryptedFrame = TvsCipher.decryptFrame(fullFrame);

      // Headers (bytes 0, 1) unchanged
      expect(decryptedFrame[0], equals(0x5A));
      expect(decryptedFrame[1], equals(0x10));

      // Payload (bytes 2, 3, 4) decrypted
      expect(decryptedFrame[2], equals(0x01));
      expect(decryptedFrame[3], equals(0x02));
      expect(decryptedFrame[4], equals(0x03));

      // Checksum and trailer unchanged
      expect(decryptedFrame[5], equals(0x50));
      expect(decryptedFrame[6], equals(0xFF));
    });

    test('Handles short frames without throwing', () {
      final shortFrame = Uint8List.fromList([0x5A, 0x10]);
      final result = TvsCipher.decryptFrame(shortFrame);
      expect(result, equals(shortFrame));
    });
  });
}
