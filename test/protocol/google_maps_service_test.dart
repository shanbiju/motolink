import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/adapters/tvs_rtr200_adapter.dart';
import 'package:motolink/core/protocol/packet_builder.dart';
import 'package:motolink/features/navigation/google_maps_service.dart';
import 'package:motolink/features/navigation/navigation_models.dart';

void main() {
  group('GoogleMapsNavigationService Tests', () {
    final gmaps = GoogleMapsNavigationService.instance;

    test('Parses turn right with distance in meters and street extraction', () {
      final parsed = gmaps.parseGoogleMapsInstruction('In 450 m, turn right onto Hosur Main Road');
      expect(parsed.maneuver, equals(ManeuverType.turnRight));
      expect(parsed.distanceMeters, equals(450));
      expect(parsed.streetName, equals('Hosur Main Road'));
    });

    test('Parses sharp left with distance in kilometers', () {
      final parsed = gmaps.parseGoogleMapsInstruction('In 1.5 km, sharp left onto Outer Ring Road');
      expect(parsed.maneuver, equals(ManeuverType.sharpLeft));
      expect(parsed.distanceMeters, equals(1500));
      expect(parsed.streetName, equals('Outer Ring Road'));
    });

    test('Parses roundabout exits correctly', () {
      final exit1 = gmaps.parseGoogleMapsInstruction('At roundabout take 1st exit onto Airport Rd');
      expect(exit1.maneuver, equals(ManeuverType.roundaboutExit1));

      final exit2 = gmaps.parseGoogleMapsInstruction('Take the 2nd exit at roundabout');
      expect(exit2.maneuver, equals(ManeuverType.roundaboutExit2));

      final exit3 = gmaps.parseGoogleMapsInstruction('Take third exit at roundabout');
      expect(exit3.maneuver, equals(ManeuverType.roundaboutExit3));
    });

    test('Parses U-turns', () {
      final uturn = gmaps.parseGoogleMapsInstruction('Make a U-turn in 300 m on NH 44');
      expect(uturn.maneuver, equals(ManeuverType.uTurnRight));
      expect(uturn.distanceMeters, equals(300));
    });

    test('Parses destination reached', () {
      final arrived = gmaps.parseGoogleMapsInstruction('You have arrived at your destination');
      expect(arrived.maneuver, equals(ManeuverType.destinationReached));
    });

    test('Builds valid RTR 200 cluster packet from parsed Google Maps instruction', () {
      final parsed = gmaps.parseGoogleMapsInstruction('In 350 m, turn right onto MG Road Boulevard');
      final adapter = TvsRtr200Adapter();
      final packet = adapter.buildNavigationPacket(parsed);

      expect(packet[0], equals(0x5B)); // Start byte 0x5B
      expect(packet[1], equals(0x01)); // Navigation Opcode 0x01
      expect(packet.last, equals(0xFF)); // Trailer
      // Length is header (2) + payload (18) + checksum (1) + trailer (1) = 22 bytes
      expect(packet.length, equals(22));

      // Sanitize street name test
      final sanitized = TvsPacketBuilder.sanitizeForLcd(parsed.streetName, maxLength: 15);
      expect(sanitized.length, lessThanOrEqualTo(15));
      expect(sanitized, equals('MG ROAD BOULEVA'));
    });
  });
}
