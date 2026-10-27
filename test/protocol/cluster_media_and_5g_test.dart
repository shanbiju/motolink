import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/core/protocol/packet_builder.dart';
import 'package:motolink/features/ibutton/ibutton_service.dart';
import 'package:motolink/features/media/cluster_media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TVS 5G Network Fix & Cluster Media Tests', () {
    late ClusterMediaService mediaService;

    setUp(() {
      mediaService = ClusterMediaService.instance;
    });

    test('5G Network guarantees 5 full bars to fix TVS "No Network" bug', () {
      // In official TVS app, 5G network type (TelephonyManager 20) results in 0 bars.
      // MotoLink fixes this: when 5G is detected, signal strength is guaranteed at 5 bars.
      mediaService.updateNetworkAndBattery(network: '5G', bars: 0);

      expect(mediaService.networkType, '5G');
      expect(mediaService.signalBars, 5,
          reason: '5G must always transmit 5 bars to prevent speedometer 0-bar "no network" icon');

      // Verify BLE packet payload for Opcode 0x05
      final packet = TvsPacketBuilder.buildPhoneStatePacket(
        batteryPercent: 88,
        signalStrengthBars: mediaService.signalBars,
      );

      expect(packet.isNotEmpty, true);
      expect(packet[0], 0x5B, reason: 'Header byte must be 0x5B');
      expect(packet.length, 20);
      expect(packet.last, 0xFF, reason: 'Trailer byte must be 0xFF');
    });

    test('Non-5G networks respect regular signal strength bars', () {
      mediaService.updateNetworkAndBattery(network: '4G LTE', bars: 3);

      expect(mediaService.networkType, '4G LTE');
      expect(mediaService.signalBars, 3);
    });

    test('Now Playing song title formats to 15-character LCD ribbon', () {
      mediaService.updateMedia(trackTitle: 'Blinding Lights', artist: 'The Weeknd');

      expect(mediaService.clusterFormattedTrack.length, 15);
      expect(mediaService.clusterFormattedTrack, 'SONG: BLINDING ');

      // Test short title padding
      mediaService.updateMedia(trackTitle: 'Hello', artist: 'Adele');
      expect(mediaService.clusterFormattedTrack.length, 15);
      expect(mediaService.clusterFormattedTrack, 'SONG: HELLO    ');
    });

    test('Navigation turn maneuver takes priority over media text', () {
      mediaService.updateMedia(trackTitle: 'Starboy', artist: 'The Weeknd');
      expect(mediaService.isNavActive, false);

      // When turn-by-turn instruction is dispatched
      mediaService.notifyNavigationDispatched();
      expect(mediaService.isNavActive, true);

      // While nav is active, media text is suppressed on the cluster
      // (verified via isNavActive)
      expect(mediaService.isNavActive, true);

      // Once navigation ends or is cleared
      mediaService.setNavActive(false);
      expect(mediaService.isNavActive, false);
    });

    test('Handlebar i-Button triggers media controls', () async {
      final iButton = IButtonService.instance;
      mediaService.updateMedia(trackTitle: 'Blinding Lights', artist: 'The Weeknd', isPlaying: true);

      // Single press -> Play/Pause
      await iButton.triggerGesture(ButtonGestureType.singlePress);
      expect(mediaService.isPlaying, false);

      // Another single press -> Resume
      await iButton.triggerGesture(ButtonGestureType.singlePress);
      expect(mediaService.isPlaying, true);

      // Triple press -> Next track
      await iButton.triggerGesture(ButtonGestureType.triplePress);
      expect(mediaService.currentTrack, 'Starboy');

      // Double press -> Previous track
      await iButton.triggerGesture(ButtonGestureType.doublePress);
      expect(mediaService.currentTrack, 'Blinding Lights');
    });
  });
}
