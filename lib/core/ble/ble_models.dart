import '../../adapters/vehicle_adapter.dart';

/// Connection and authentication state machine stages
enum ConnectionStage {
  disconnected,
  scanning,
  connecting,
  awaitingPin,
  authenticated,
  streamingTelemetry,
  reconnecting,
  error,
}

extension ConnectionStageExtension on ConnectionStage {
  String get displayName {
    switch (this) {
      case ConnectionStage.disconnected:
        return 'Disconnected';
      case ConnectionStage.scanning:
        return 'Scanning for Motorcycle';
      case ConnectionStage.connecting:
        return 'Connecting to Cluster';
      case ConnectionStage.awaitingPin:
        return 'Awaiting Dynamic PIN';
      case ConnectionStage.authenticated:
        return 'Bonded & Authenticated';
      case ConnectionStage.streamingTelemetry:
        return 'Live Telemetry Active';
      case ConnectionStage.reconnecting:
        return 'Waiting for Bike Ignition (Auto-Connect)';
      case ConnectionStage.error:
        return 'Connection Error';
    }
  }

  bool get isConnected =>
      this == ConnectionStage.authenticated ||
      this == ConnectionStage.streamingTelemetry;
}

/// Discovered TVS motorcycle BLE peripheral
class DiscoveredBike {
  final String id;
  final String name;
  final int rssi;
  final VehicleAdapter adapter;
  final bool isPaired;
  final bool isNearby;
  final bool isTvs;

  const DiscoveredBike({
    required this.id,
    required this.name,
    required this.rssi,
    required this.adapter,
    this.isPaired = false,
    this.isNearby = true,
    this.isTvs = true,
  });

  DiscoveredBike copyWith({
    String? id,
    String? name,
    int? rssi,
    VehicleAdapter? adapter,
    bool? isPaired,
    bool? isNearby,
    bool? isTvs,
  }) {
    return DiscoveredBike(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      adapter: adapter ?? this.adapter,
      isPaired: isPaired ?? this.isPaired,
      isNearby: isNearby ?? this.isNearby,
      isTvs: isTvs ?? this.isTvs,
    );
  }
}
