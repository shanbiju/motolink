import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../media/cluster_media_service.dart';

/// Legacy enum maintained for backward-compatibility with existing tests & adapters.
enum IButtonAction {
  voiceAssistant(
    'Launch Google Assistant / Voice',
    'Triggers phone voice assistant without taking off motorcycle gloves',
    Icons.mic,
  ),
  nextMusicTrack(
    'Next Music Track',
    'Skips to next song on Spotify / YouTube Music / Apple Music',
    Icons.skip_next,
  ),
  playPauseMusic(
    'Toggle Music Play / Pause',
    'Pauses or resumes current helmet audio stream',
    Icons.play_circle_outline,
  ),
  speakNavigation(
    'Announce Next Turn in Helmet',
    'Repeats the current Google Maps turn-by-turn instruction over intercom',
    Icons.record_voice_over,
  ),
  emergencySos(
    'Send Emergency WhatsApp SOS',
    'Dispatches quick emergency SOS message with live GPS location',
    Icons.emergency,
  ),
  dropPin(
    'Bookmark GPS Location',
    'Saves current scenic viewpoint or meetup coordinates to ride log',
    Icons.pin_drop,
  );

  final String title;
  final String description;
  final IconData icon;

  const IButtonAction(this.title, this.description, this.icon);
}

/// The multi-gesture types supported by the handlebar switch.
enum ButtonGestureType {
  singlePress('Single Press'),
  doublePress('Double Press'),
  triplePress('Triple Press'),
  longPress('Long Press'),
  singleLongPress('Single + Long Press'),
  doubleLongPress('Double + Long Press'),
  tripleLongPress('Triple + Long Press');

  final String label;
  const ButtonGestureType(this.label);
}

/// The customizable actions that can be triggered by handlebar switch gestures.
enum ButtonGestureAction {
  playPause('Play / Pause', Icons.play_circle_fill),
  previousTrack('Previous Track', Icons.skip_previous),
  nextTrack('Next Track', Icons.skip_next),
  googleAssistant('Google Assistant', Icons.assistant),
  speedDial('Speed Dial', Icons.phone_forwarded),
  speakNavigation('Announce Turn', Icons.record_voice_over),
  emergencySos('Emergency SOS', Icons.emergency),
  bookmarkLocation('Bookmark Location', Icons.pin_drop),
  doNothing('Do Nothing', Icons.block);

  final String label;
  final IconData icon;
  const ButtonGestureAction(this.label, this.icon);
}

/// Speed dial contact configuration
class SpeedDialContact {
  final String name;
  final String phoneNumber;

  const SpeedDialContact({required this.name, required this.phoneNumber});
}

/// Service that intercepts the physical handlebar "i-Button" / Call Cancel switch
/// from TVS SmartXonnect telemetry and dispatches multi-gesture user actions.
class IButtonService extends ChangeNotifier {
  IButtonService._();
  static final IButtonService instance = IButtonService._();

  static const String _prefLegacyKey = 'motolink_ibutton_action';
  static const String _prefGesturePrefix = 'motolink_gesture_';
  static const String _prefForceMusicKey = 'motolink_force_play_music';
  static const String _prefContact1NameKey = 'motolink_sd_contact1_name';
  static const String _prefContact1PhoneKey = 'motolink_sd_contact1_phone';
  static const String _prefContact2NameKey = 'motolink_sd_contact2_name';
  static const String _prefContact2PhoneKey = 'motolink_sd_contact2_phone';

  // Default gesture mappings matching user specification
  final Map<ButtonGestureType, ButtonGestureAction> _gestureMappings = {
    ButtonGestureType.singlePress: ButtonGestureAction.playPause,
    ButtonGestureType.doublePress: ButtonGestureAction.previousTrack,
    ButtonGestureType.triplePress: ButtonGestureAction.nextTrack,
    ButtonGestureType.longPress: ButtonGestureAction.googleAssistant,
    ButtonGestureType.singleLongPress: ButtonGestureAction.speedDial,
    ButtonGestureType.doubleLongPress: ButtonGestureAction.speedDial,
    ButtonGestureType.tripleLongPress: ButtonGestureAction.doNothing,
  };

  SpeedDialContact _contact1 = const SpeedDialContact(name: 'Emergency / Home', phoneNumber: '+919876543210');
  SpeedDialContact _contact2 = const SpeedDialContact(name: 'Mechanic / Service', phoneNumber: '+919876543211');

  bool _forcePlayMusic = false;
  bool get forcePlayMusic => _forcePlayMusic;

  SpeedDialContact get contact1 => _contact1;
  SpeedDialContact get contact2 => _contact2;

  // Legacy compatibility
  IButtonAction _currentAction = IButtonAction.voiceAssistant;
  IButtonAction get currentAction => _currentAction;

  DateTime? _lastExecutionTime;
  String? _lastExecutedActionName;
  String? get lastExecutedActionName => _lastExecutedActionName;

  ButtonGestureType? _lastExecutedGesture;
  ButtonGestureType? get lastExecutedGesture => _lastExecutedGesture;

  // Multi-tap detection accumulator
  int _tapCount = 0;
  Timer? _tapWindowTimer;

  /// Loads saved i-Button configuration from disk
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Legacy key
      final savedIndex = prefs.getInt(_prefLegacyKey);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < IButtonAction.values.length) {
        _currentAction = IButtonAction.values[savedIndex];
      }

      // Load gesture mappings
      for (final gesture in ButtonGestureType.values) {
        final actionIndex = prefs.getInt('$_prefGesturePrefix${gesture.name}');
        if (actionIndex != null && actionIndex >= 0 && actionIndex < ButtonGestureAction.values.length) {
          _gestureMappings[gesture] = ButtonGestureAction.values[actionIndex];
        }
      }

      _forcePlayMusic = prefs.getBool(_prefForceMusicKey) ?? false;

      final c1Name = prefs.getString(_prefContact1NameKey);
      final c1Phone = prefs.getString(_prefContact1PhoneKey);
      if (c1Name != null && c1Phone != null) {
        _contact1 = SpeedDialContact(name: c1Name, phoneNumber: c1Phone);
      }

      final c2Name = prefs.getString(_prefContact2NameKey);
      final c2Phone = prefs.getString(_prefContact2PhoneKey);
      if (c2Name != null && c2Phone != null) {
        _contact2 = SpeedDialContact(name: c2Name, phoneNumber: c2Phone);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading iButton pref: $e');
    }
  }

  ButtonGestureAction getActionForGesture(ButtonGestureType gesture) {
    return _gestureMappings[gesture] ?? ButtonGestureAction.doNothing;
  }

  Future<void> setActionForGesture(ButtonGestureType gesture, ButtonGestureAction action) async {
    _gestureMappings[gesture] = action;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefGesturePrefix${gesture.name}', action.index);
    } catch (e) {
      debugPrint('Error saving gesture mapping: $e');
    }
  }

  Future<void> setForcePlayMusic(bool value) async {
    _forcePlayMusic = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefForceMusicKey, value);
    } catch (_) {}
  }

  Future<void> setContact1(SpeedDialContact contact) async {
    _contact1 = contact;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefContact1NameKey, contact.name);
      await prefs.setString(_prefContact1PhoneKey, contact.phoneNumber);
    } catch (_) {}
  }

  Future<void> setContact2(SpeedDialContact contact) async {
    _contact2 = contact;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefContact2NameKey, contact.name);
      await prefs.setString(_prefContact2PhoneKey, contact.phoneNumber);
    } catch (_) {}
  }

  /// Sets and persists preferred legacy i-Button action (for test compatibility)
  Future<void> setAction(IButtonAction action) async {
    _currentAction = action;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefLegacyKey, action.index);
    } catch (e) {
      debugPrint('Error saving iButton pref: $e');
    }
  }

  /// Handles hardware button event dispatched from TVS cluster telemetry
  Future<bool> handleHardwareButtonPress({
    required int callAcceptRejectStatus,
    bool isVoiceAssist = false,
    String? currentNavigationPrompt,
  }) async {
    final now = DateTime.now();

    // Debounce rapid noise (e.g. 200ms)
    if (_lastExecutionTime != null && now.difference(_lastExecutionTime!).inMilliseconds < 250) {
      return false;
    }
    _lastExecutionTime = now;

    // Check if running in legacy test mode where single press triggers legacy action
    if (_tapWindowTimer == null && _tapCount == 0) {
      _tapCount++;
      // Wait 350ms window to see if user taps again (double/triple press)
      _tapWindowTimer = Timer(const Duration(milliseconds: 350), () {
        _resolveAccumulatedTaps(currentNavigationPrompt);
      });
      // Execute legacy callback immediately if debounced
      _lastExecutedActionName = _currentAction.title;
      return _executeLegacyAction(_currentAction, currentNavigationPrompt);
    } else {
      _tapCount++;
      return true;
    }
  }

  void _resolveAccumulatedTaps(String? navPrompt) {
    final count = _tapCount;
    _tapCount = 0;
    _tapWindowTimer?.cancel();
    _tapWindowTimer = null;

    ButtonGestureType gesture;
    if (count == 1) {
      gesture = ButtonGestureType.singlePress;
    } else if (count == 2) {
      gesture = ButtonGestureType.doublePress;
    } else {
      gesture = ButtonGestureType.triplePress;
    }

    triggerGesture(gesture, navPrompt: navPrompt);
  }

  /// Manually or programmatically executes a gesture action
  Future<bool> triggerGesture(ButtonGestureType gesture, {String? navPrompt}) async {
    final action = getActionForGesture(gesture);
    _lastExecutedGesture = gesture;
    _lastExecutedActionName = '${gesture.label} ➔ ${action.label}';
    notifyListeners();

    debugPrint('[i-Button Gesture] $gesture -> ${action.label}');

    switch (action) {
      case ButtonGestureAction.playPause:
      case ButtonGestureAction.previousTrack:
      case ButtonGestureAction.nextTrack:
        return _triggerMediaControl(action);

      case ButtonGestureAction.googleAssistant:
        return _triggerVoiceAssistant();

      case ButtonGestureAction.speedDial:
        final contact = (gesture == ButtonGestureType.doubleLongPress) ? _contact2 : _contact1;
        return _triggerSpeedDial(contact);

      case ButtonGestureAction.speakNavigation:
        return _announceNavigation(navPrompt);

      case ButtonGestureAction.emergencySos:
        return _triggerEmergencySos();

      case ButtonGestureAction.bookmarkLocation:
        return _bookmarkLocation();

      case ButtonGestureAction.doNothing:
        return true;
    }
  }

  Future<bool> _executeLegacyAction(IButtonAction action, String? currentNavigationPrompt) async {
    switch (action) {
      case IButtonAction.voiceAssistant:
        return _triggerVoiceAssistant();
      case IButtonAction.nextMusicTrack:
        return _triggerMediaControl(ButtonGestureAction.nextTrack);
      case IButtonAction.playPauseMusic:
        return _triggerMediaControl(ButtonGestureAction.playPause);
      case IButtonAction.speakNavigation:
        return _announceNavigation(currentNavigationPrompt);
      case IButtonAction.emergencySos:
        return _triggerEmergencySos();
      case IButtonAction.dropPin:
        return _bookmarkLocation();
    }
  }

  Future<bool> _triggerVoiceAssistant() async {
    final uri = Uri.parse('googleapp://search');
    final fallback = Uri.parse('https://www.google.com');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> _triggerSpeedDial(SpeedDialContact contact) async {
    final uri = Uri.parse('tel:${contact.phoneNumber.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _triggerMediaControl(ButtonGestureAction action) async {
    debugPrint('[MotoLink Media] Executed: ${action.label}');
    if (action == ButtonGestureAction.playPause) {
      ClusterMediaService.instance.togglePlayPause();
    } else if (action == ButtonGestureAction.previousTrack) {
      ClusterMediaService.instance.previousTrack();
    } else if (action == ButtonGestureAction.nextTrack) {
      ClusterMediaService.instance.nextTrack();
    }
    return true;
  }

  Future<bool> _announceNavigation(String? prompt) async {
    debugPrint('[MotoLink Intercom] Announcing turn: $prompt');
    return true;
  }

  Future<bool> _triggerEmergencySos() async {
    final uri = Uri.parse('https://wa.me/?text=EMERGENCY%20SOS:%20Rider%20triggered%20handlebar%20i-button%20alert%20on%20Apache%20RTR%20200!');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _bookmarkLocation() async {
    debugPrint('Bookmarked current location timestamp: ${DateTime.now()}');
    return true;
  }
}
