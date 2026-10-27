import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/core/protocol/checksum.dart';
import 'package:motolink/core/protocol/cipher.dart';
import 'package:motolink/core/protocol/frame_parser.dart';

void main() {
  group('TvsFrameParser Protocol Tests', () {
    late TvsFrameParser parser;

    setUp(() {
      parser = TvsFrameParser();
    });

    Uint8List makeTestFrame(int startByte, int opcode, List<int> plainPayload) {
      final padded = List<int>.filled(16, 0);
      for (int i = 0; i < plainPayload.length && i < 16; i++) {
        padded[i] = plainPayload[i];
      }
      final encryptedPayload = TvsCipher.cryptPayload(padded);
      final rawBeforeChecksum = [startByte, opcode, ...encryptedPayload];
      final checksum = TvsChecksum.compute(rawBeforeChecksum);
      return Uint8List.fromList([...rawBeforeChecksum, checksum, 0x0D]);
    }

    test('Parses complete single frame successfully', () {
      final plainPayload = [0x2A, 0x14, 0x05];
      final raw = makeTestFrame(0x5A, 0x10, plainPayload);

      final frames = parser.feed(raw);
      expect(frames.length, equals(1));
      expect(frames[0].startByte, equals(0x5A));
      expect(frames[0].opcode, equals(0x10));
      expect(frames[0].plainPayload.sublist(0, 3), equals(Uint8List.fromList(plainPayload)));
    });

    test('Handles fragmented packets across multiple stream chunks', () {
      final plainPayload = [0x11, 0x22, 0x33, 0x44, 0x55];
      final raw = makeTestFrame(0x5A, 0x11, plainPayload);

      // Split raw packet into 3 chunks
      final chunk1 = raw.sublist(0, 3);
      final chunk2 = raw.sublist(3, 6);
      final chunk3 = raw.sublist(6);

      var frames = parser.feed(chunk1);
      expect(frames.isEmpty, isTrue);

      frames = parser.feed(chunk2);
      expect(frames.isEmpty, isTrue);

      frames = parser.feed(chunk3);
      expect(frames.length, equals(1));
      expect(frames[0].opcode, equals(0x11));
      expect(frames[0].plainPayload.sublist(0, 5), equals(Uint8List.fromList(plainPayload)));
    });

    test('Handles multiple back-to-back frames in a single chunk', () {
      final frame1 = makeTestFrame(0x5A, 0x10, [0x01, 0x02]);
      final frame2 = makeTestFrame(0x5A, 0x11, [0x03, 0x04]);

      final combined = Uint8List.fromList([...frame1, ...frame2]);
      final frames = parser.feed(combined);

      expect(frames.length, equals(2));
      expect(frames[0].opcode, equals(0x10));
      expect(frames[1].opcode, equals(0x11));
    });

    test('Recovers gracefully from corrupted leading noise bytes', () {
      final validFrame = makeTestFrame(0x5A, 0x10, [0x77, 0x88]);
      final noisyStream = Uint8List.fromList([
        0x12, 0x34, 0x56, // Garbage noise
        ...validFrame,
      ]);

      final frames = parser.feed(noisyStream);
      expect(frames.length, equals(1));
      expect(frames[0].opcode, equals(0x10));
      expect(frames[0].plainPayload.sublist(0, 2), equals(Uint8List.fromList([0x77, 0x88])));
    });

    test('Rejects frame with corrupted checksum and continues parsing next valid frame', () {
      final corruptedFrame = makeTestFrame(0x5A, 0x10, [0x11, 0x22]);
      // Corrupt the checksum byte
      corruptedFrame[corruptedFrame.length - 2] ^= 0x55;

      final validFrame = makeTestFrame(0x5A, 0x12, [0x99]);

      final stream = Uint8List.fromList([...corruptedFrame, ...validFrame]);
      final frames = parser.feed(stream);

      expect(frames.length, equals(1));
      expect(frames[0].opcode, equals(0x12));
      expect(frames[0].plainPayload.sublist(0, 1), equals(Uint8List.fromList([0x99])));
    });

    test('Buffer overflow protection discards runaway garbage', () {
      // Feed garbage larger than buffer max
      final hugeGarbage = Uint8List(1200);
      hugeGarbage.fillRange(0, 1200, 0xAA);

      final frames = parser.feed(hugeGarbage);
      expect(frames.isEmpty, isTrue);

      // Now feed a valid frame; parser must still work
      final validFrame = makeTestFrame(0x5A, 0x10, [0x50]);
      final recoveredFrames = parser.feed(validFrame);
      expect(recoveredFrames.length, equals(1));
    });
  });
}
