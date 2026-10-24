import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/telemetry/telemetry_models.dart';
import 'ble_connection_manager.dart';
import 'ble_models.dart';

/// Global singleton ChangeNotifierProvider for the BLE connection manager
final bleManagerProvider = ChangeNotifierProvider<BleConnectionManager>((ref) {
  return BleConnectionManager();
});

/// Current connection state machine stage
final connectionStageProvider = Provider<ConnectionStage>((ref) {
  return ref.watch(bleManagerProvider).stage;
});

/// Live telemetry stream
final telemetryProvider = Provider<TelemetryData>((ref) {
  return ref.watch(bleManagerProvider).telemetry;
});

/// Discovered motorcycles during scan
final discoveredBikesProvider = Provider<List<DiscoveredBike>>((ref) {
  return ref.watch(bleManagerProvider).discoveredBikes;
});
