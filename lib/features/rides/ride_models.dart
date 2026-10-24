
/// Model representing a completed motorcycle ride log
class RideRecord {
  final String id;
  final String title;
  final String date;
  final double distanceKm;
  final Duration duration;
  final int topSpeedKmh;
  final double bestZeroToSixtySec;
  final int maxLeanAngleDeg;
  final double maxGForce;
  final double altitudeMeters;
  final String startTime;
  final String endTime;
  final double latitude;
  final double longitude;
  final String locationCode;

  const RideRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.topSpeedKmh,
    required this.bestZeroToSixtySec,
    required this.maxLeanAngleDeg,
    required this.maxGForce,
    required this.altitudeMeters,
    required this.startTime,
    required this.endTime,
    required this.latitude,
    required this.longitude,
    required this.locationCode,
  });

  String get formattedDuration {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '$days Days $hours hr $minutes min $seconds sec';
    } else if (hours > 0) {
      return '$hours hr $minutes min $seconds sec';
    } else {
      return '$minutes min $seconds sec';
    }
  }

  /// Default demo ride records matching official TVS Apache screenshots
  static List<RideRecord> defaultRides() {
    return [
      const RideRecord(
        id: 'ride_01',
        title: 'Ride 05:11 PM',
        date: '12thSep',
        distanceKm: 54.2,
        duration: Duration(days: 13, hours: 16, minutes: 27, seconds: 6),
        topSpeedKmh: 99,
        bestZeroToSixtySec: 9.9,
        maxLeanAngleDeg: 27,
        maxGForce: 0.1,
        altitudeMeters: 0.0,
        startTime: '05:11 PM',
        endTime: '09:38 AM',
        latitude: 10.3705,
        longitude: 76.2892,
        locationCode: '985R+3GJ Kanakamala',
      ),
      const RideRecord(
        id: 'ride_02',
        title: 'Ride 10:47 AM',
        date: '16thJul',
        distanceKm: 2.9,
        duration: Duration(minutes: 22, seconds: 58),
        topSpeedKmh: 68,
        bestZeroToSixtySec: 10.4,
        maxLeanAngleDeg: 22,
        maxGForce: 0.2,
        altitudeMeters: 14.2,
        startTime: '10:47 AM',
        endTime: '11:10 AM',
        latitude: 10.3680,
        longitude: 76.2870,
        locationCode: '985R+2EH Vellapadi',
      ),
      const RideRecord(
        id: 'ride_03',
        title: 'Ride 06:39 PM',
        date: '11thJul',
        distanceKm: 4.6,
        duration: Duration(minutes: 8, seconds: 40),
        topSpeedKmh: 82,
        bestZeroToSixtySec: 9.7,
        maxLeanAngleDeg: 25,
        maxGForce: 0.25,
        altitudeMeters: 18.0,
        startTime: '06:39 PM',
        endTime: '06:48 PM',
        latitude: 10.3720,
        longitude: 76.2910,
        locationCode: '985R+4FK Kodakara',
      ),
    ];
  }
}
