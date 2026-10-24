import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/features/ibutton/ibutton_service.dart';
import 'package:motolink/features/telemetry/trip_recorder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multi-Gesture Handlebar Engine Tests', () {
    final ibutton = IButtonService.instance;

    test('Initializes with default gesture mappings and speed dial contacts', () async {
      await ibutton.init();
      expect(
        ibutton.getActionForGesture(ButtonGestureType.singlePress),
        equals(ButtonGestureAction.playPause),
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.doublePress),
        equals(ButtonGestureAction.previousTrack),
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.triplePress),
        equals(ButtonGestureAction.nextTrack),
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.longPress),
        equals(ButtonGestureAction.googleAssistant),
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.singleLongPress),
        equals(ButtonGestureAction.speedDial),
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.doubleLongPress),
        equals(ButtonGestureAction.speedDial),
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.tripleLongPress),
        equals(ButtonGestureAction.doNothing),
      );
      expect(ibutton.forcePlayMusic, isFalse);
      expect(ibutton.contact1.phoneNumber, isNotEmpty);
    });

    test('Can configure custom gesture mappings and persist them', () async {
      await ibutton.setActionForGesture(
        ButtonGestureType.triplePress,
        ButtonGestureAction.emergencySos,
      );
      expect(
        ibutton.getActionForGesture(ButtonGestureType.triplePress),
        equals(ButtonGestureAction.emergencySos),
      );

      await ibutton.setForcePlayMusic(true);
      expect(ibutton.forcePlayMusic, isTrue);

      await ibutton.setContact1(const SpeedDialContact(
        name: 'Rider Base',
        phoneNumber: '+919999988888',
      ));
      expect(ibutton.contact1.name, equals('Rider Base'));
      expect(ibutton.contact1.phoneNumber, equals('+919999988888'));
    });

    test('Executes gesture actions and updates last executed state', () async {
      final success = await ibutton.triggerGesture(ButtonGestureType.singlePress);
      expect(success, isTrue);
      expect(ibutton.lastExecutedGesture, equals(ButtonGestureType.singlePress));
      expect(ibutton.lastExecutedActionName, contains('Play / Pause'));
    });
  });

  group('TripRecorderService Telemetry Tests', () {
    final recorder = TripRecorderService.instance;

    test('Initializes default telemetry values', () async {
      await recorder.init();
      expect(recorder.odometerKm, equals(8817.6));
      expect(recorder.economyKmL, equals(53.0));
      expect(recorder.batteryVoltage, equals(12.3));
      expect(recorder.isRecording, isFalse);
    });

    test('Starts and stops live trip recording', () {
      expect(recorder.isRecording, isFalse);
      recorder.startRecording();
      expect(recorder.isRecording, isTrue);
      expect(recorder.gpsFixes, equals(1));

      recorder.stopRecording();
      expect(recorder.isRecording, isFalse);
      expect(recorder.tripLogs.length, greaterThanOrEqualTo(1));
      expect(recorder.tripLogs.first.title, contains('City Ride'));
    });

    test('Updates live telemetry metrics and notifies listeners', () {
      recorder.updateTelemetry(
        speedKmh: 45.0,
        odoKm: 8820.5,
        economy: 55.2,
        batteryV: 12.8,
        dte: 42,
      );

      expect(recorder.currentSpeedKmh, equals(45.0));
      expect(recorder.odometerKm, equals(8820.5));
      expect(recorder.economyKmL, equals(55.2));
      expect(recorder.batteryVoltage, equals(12.8));
      expect(recorder.dteKm, equals(42));
    });
  });
}
