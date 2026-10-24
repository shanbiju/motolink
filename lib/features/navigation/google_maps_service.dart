import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'navigation_models.dart';

/// Service connecting Google Maps Navigation with the TVS SmartXonnect BLE Cluster.
class GoogleMapsNavigationService {
  GoogleMapsNavigationService._();

  static final GoogleMapsNavigationService instance =
      GoogleMapsNavigationService._();

  /// Launches Google Maps Turn-by-Turn Navigation with Two-Wheeler (Motorcycle) Mode.
  /// Disassembled from TVS Connect: `openGoogleMapsWithNavigation("google.navigation:q=...&mode=2w")`
  Future<bool> launchGoogleMapsNavigation({
    required String destination,
    bool motorcycleMode = true,
  }) async {
    final mode = motorcycleMode ? '2w' : 'd';
    final nativeUri = Uri.parse(
      'google.navigation:q=${Uri.encodeComponent(destination)}&mode=$mode',
    );

    final webFallbackUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=${motorcycleMode ? 'two_wheeler' : 'driving'}',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(webFallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      return false;
    }
  }

  /// Parses text from Google Maps Turn-by-Turn notifications or input
  /// (e.g. "In 450 m, turn right onto Hosur Main Road")
  /// and converts it into a structured [NavigationInstruction] for TVS cluster.
  NavigationInstruction parseGoogleMapsInstruction(String rawText, {int? defaultDistanceMeters}) {
    final lower = rawText.toLowerCase().trim();

    // 1. Detect maneuver
    var maneuver = ManeuverType.straight;
    if (lower.contains('u-turn') || lower.contains('uturn')) {
      maneuver = lower.contains('left') ? ManeuverType.uTurnLeft : ManeuverType.uTurnRight;
    } else if (lower.contains('sharp right')) {
      maneuver = ManeuverType.sharpRight;
    } else if (lower.contains('sharp left')) {
      maneuver = ManeuverType.sharpLeft;
    } else if (lower.contains('slight right') || lower.contains('bear right') || lower.contains('keep right')) {
      maneuver = ManeuverType.slightRight;
    } else if (lower.contains('slight left') || lower.contains('bear left') || lower.contains('keep left')) {
      maneuver = ManeuverType.slightLeft;
    } else if (lower.contains('turn right') || lower.contains('take the right') || lower.contains('right onto')) {
      maneuver = ManeuverType.turnRight;
    } else if (lower.contains('turn left') || lower.contains('take the left') || lower.contains('left onto')) {
      maneuver = ManeuverType.turnLeft;
    } else if (lower.contains('roundabout') || lower.contains('rotary')) {
      if (lower.contains('1st') || lower.contains('first')) {
        maneuver = ManeuverType.roundaboutExit1;
      } else if (lower.contains('2nd') || lower.contains('second')) {
        maneuver = ManeuverType.roundaboutExit2;
      } else if (lower.contains('3rd') || lower.contains('third')) {
        maneuver = ManeuverType.roundaboutExit3;
      } else {
        maneuver = ManeuverType.roundaboutExit4;
      }
    } else if (lower.contains('arrived') || lower.contains('destination')) {
      maneuver = ManeuverType.destinationReached;
    }

    // 2. Extract distance
    var distanceMeters = defaultDistanceMeters ?? 200;
    final kmRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:km|kilometers)');
    final mRegex = RegExp(r'(\d+)\s*(?:m|meters|metres)');

    final kmMatch = kmRegex.firstMatch(lower);
    if (kmMatch != null) {
      final km = double.tryParse(kmMatch.group(1) ?? '1.0') ?? 1.0;
      distanceMeters = (km * 1000).round();
    } else {
      final mMatch = mRegex.firstMatch(lower);
      if (mMatch != null) {
        distanceMeters = int.tryParse(mMatch.group(1) ?? '200') ?? 200;
      }
    }

    // 3. Extract street name
    var street = rawText;
    final ontoIdx = lower.indexOf('onto ');
    final toIdx = lower.indexOf('toward ');
    final onIdx = lower.indexOf('on ');

    if (ontoIdx != -1) {
      street = rawText.substring(ontoIdx + 5).trim();
    } else if (toIdx != -1) {
      street = rawText.substring(toIdx + 7).trim();
    } else if (onIdx != -1) {
      street = rawText.substring(onIdx + 3).trim();
    }

    // Strip leading punctuation or distance prefixes if remaining
    street = street.replaceAll(RegExp(r'^(in\s+\d+[\w\s]+,\s*)', caseSensitive: false), '');

    return NavigationInstruction(
      maneuver: maneuver,
      distanceMeters: distanceMeters,
      streetName: street.isNotEmpty ? street : 'MAIN ROAD',
    );
  }
}
