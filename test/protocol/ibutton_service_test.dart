import 'package:flutter_test/flutter_test.dart';
import 'package:motolink/features/ibutton/ibutton_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IButtonService Tests', () {
    final ibutton = IButtonService.instance;

    test('Initializes with default voiceAssistant action', () async {
      await ibutton.init();
      expect(ibutton.currentAction, equals(IButtonAction.voiceAssistant));
    });

    test('Can switch and persist different handlebar actions', () async {
      await ibutton.setAction(IButtonAction.nextMusicTrack);
      expect(ibutton.currentAction, equals(IButtonAction.nextMusicTrack));

      await ibutton.setAction(IButtonAction.emergencySos);
      expect(ibutton.currentAction, equals(IButtonAction.emergencySos));

      await ibutton.setAction(IButtonAction.speakNavigation);
      expect(ibutton.currentAction, equals(IButtonAction.speakNavigation));
    });

    test('Handles hardware button trigger and debounces rapid presses', () async {
      await ibutton.setAction(IButtonAction.dropPin);

      // First physical press
      final firstResult = await ibutton.handleHardwareButtonPress(
        callAcceptRejectStatus: 2,
      );
      expect(firstResult, isTrue);
      expect(ibutton.lastExecutedActionName, equals(IButtonAction.dropPin.title));

      // Immediate second press within debounce window (1500ms) should be skipped
      final secondResult = await ibutton.handleHardwareButtonPress(
        callAcceptRejectStatus: 2,
      );
      expect(secondResult, isFalse);
    });
  });
}
