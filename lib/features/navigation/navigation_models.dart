enum ManeuverType {
  straight,
  slightRight,
  turnRight,
  sharpRight,
  slightLeft,
  turnLeft,
  sharpLeft,
  uTurnRight,
  uTurnLeft,
  roundaboutExit1,
  roundaboutExit2,
  roundaboutExit3,
  roundaboutExit4,
  destinationReached,
}

extension ManeuverTypeExtension on ManeuverType {
  String get label {
    switch (this) {
      case ManeuverType.straight:
        return 'Continue Straight';
      case ManeuverType.slightRight:
        return 'Slight Right';
      case ManeuverType.turnRight:
        return 'Turn Right';
      case ManeuverType.sharpRight:
        return 'Sharp Right';
      case ManeuverType.slightLeft:
        return 'Slight Left';
      case ManeuverType.turnLeft:
        return 'Turn Left';
      case ManeuverType.sharpLeft:
        return 'Sharp Left';
      case ManeuverType.uTurnRight:
        return 'U-Turn (Right)';
      case ManeuverType.uTurnLeft:
        return 'U-Turn (Left)';
      case ManeuverType.roundaboutExit1:
        return 'Roundabout (Exit 1)';
      case ManeuverType.roundaboutExit2:
        return 'Roundabout (Exit 2)';
      case ManeuverType.roundaboutExit3:
        return 'Roundabout (Exit 3)';
      case ManeuverType.roundaboutExit4:
        return 'Roundabout (Exit 4)';
      case ManeuverType.destinationReached:
        return 'Destination Reached';
    }
  }

  /// Maps maneuver enum into the TVS Apache RTR 200 LCD character glyph code.
  /// Disassembled from TVS Connect: `ManeuverUtils.mapPictoIdForU400`
  int get rtr200LcdGlyphCode {
    switch (this) {
      case ManeuverType.straight:
        return 0x41; // 'A'
      case ManeuverType.slightRight:
      case ManeuverType.turnRight:
        return 0x42; // 'B'
      case ManeuverType.slightLeft:
      case ManeuverType.turnLeft:
        return 0x43; // 'C'
      case ManeuverType.sharpRight:
        return 0x44; // 'D'
      case ManeuverType.sharpLeft:
        return 0x45; // 'E'
      case ManeuverType.uTurnRight:
        return 0x46; // 'F'
      case ManeuverType.uTurnLeft:
        return 0x47; // 'G'
      case ManeuverType.roundaboutExit1:
        return 0x48; // 'H'
      case ManeuverType.roundaboutExit2:
        return 0x49; // 'I'
      case ManeuverType.roundaboutExit3:
        return 0x4A; // 'J'
      case ManeuverType.roundaboutExit4:
        return 0x4B; // 'K'
      case ManeuverType.destinationReached:
        return 0x41; // 'A'
    }
  }

  String get glyphLetter => String.fromCharCode(rtr200LcdGlyphCode);
}

class NavigationInstruction {
  final ManeuverType maneuver;
  final int distanceMeters;
  final String streetName;
  final int? etaMinutes;

  const NavigationInstruction({
    required this.maneuver,
    required this.distanceMeters,
    required this.streetName,
    this.etaMinutes,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceMeters m';
  }
}
