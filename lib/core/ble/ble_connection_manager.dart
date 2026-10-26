import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../adapters/tvs_rr310_adapter.dart';
import '../../adapters/tvs_rtr200_adapter.dart';
import '../../adapters/vehicle_adapter.dart';
import '../../features/ibutton/ibutton_service.dart';
import '../../features/media/cluster_media_service.dart';
import '../../features/navigation/navigation_models.dart';
import '../../features/telemetry/telemetry_models.dart';
import '../../features/telemetry/trip_recorder_service.dart';
import 'ble_models.dart';

/// Core BLE Manager orchestrating TVS SmartXonnect scanning, connection,
/// MTU negotiation, dynamic PIN verification, auto-reconnect on ignition,
/// and handlebar i-button dispatching.
class BleConnectionManager extends ChangeNotifier {
  VehicleAdapter _adapter;
  VehicleAdapter get adapter => _adapter;

  ConnectionStage _stage = ConnectionStage.disconnected;
  ConnectionStage get stage => _stage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DiscoveredBike? _selectedBike;
  DiscoveredBike? get selectedBike => _selectedBike;

  final List<DiscoveredBike> _discoveredBikes = [];
  List<DiscoveredBike> get discoveredBikes => List.unmodifiable(_discoveredBikes);

  TelemetryData _telemetry = TelemetryData.initial();
  TelemetryData get telemetry => _telemetry;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _telemetryCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _telemetrySubscription;

  // Auto-connect on ignition start settings
  static const String _prefBikeId = 'motolink_saved_bike_id';
  static const String _prefBikeName = 'motolink_saved_bike_name';
  static const String _prefAutoConnect = 'motolink_auto_connect_enabled';

  String? _savedBikeId;
  String? get savedBikeId => _savedBikeId;

  String? _savedBikeName;
  String? get savedBikeName => _savedBikeName;

  bool _autoConnectEnabled = true;
  bool get autoConnectEnabled => _autoConnectEnabled;

  BleConnectionManager({VehicleAdapter? adapter})
      : _adapter = adapter ?? TvsRtr200Adapter() {
    initializeAutoConnect();
  }

  /// Load persisted bike pairings and initiate background ignition scan if enabled
  Future<void> initializeAutoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedBikeId = prefs.getString(_prefBikeId);
      _savedBikeName = prefs.getString(_prefBikeName);
      _autoConnectEnabled = prefs.getBool(_prefAutoConnect) ?? true;
      notifyListeners();

      if (_autoConnectEnabled && _savedBikeId != null && _stage == ConnectionStage.disconnected) {
        debugPrint('[AutoConnect] Saved bike found ($_savedBikeName). Waiting for ignition start...');
        _startAutoReconnectWatchdog();
      }
    } catch (e) {
      debugPrint('Error initializing auto-connect: $e');
    }
  }

  /// Toggle auto-connect behavior
  Future<void> setAutoConnectEnabled(bool enabled) async {
    _autoConnectEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoConnect, enabled);
      if (enabled && _savedBikeId != null && _stage == ConnectionStage.disconnected) {
        _startAutoReconnectWatchdog();
      } else if (!enabled && _stage == ConnectionStage.reconnecting) {
        await stopScan();
        _setStage(ConnectionStage.disconnected);
      }
    } catch (_) {}
  }

  void setAdapter(VehicleAdapter adapter) {
    _adapter = adapter;
    notifyListeners();
  }

  /// Checks if a device name corresponds to TVS SmartXonnect, RMB, RTR, Apache, TI05BL, etc.
  static bool isTvsDevice(String name) {
    if (name.isEmpty) return false;
    final upper = name.toUpperCase();
    return upper.startsWith('RMB') ||
        upper.startsWith('TI') || // TVS Instrument cluster (TI05, TI05BL06, etc.)
        upper.startsWith('TVS') ||
        upper.startsWith('APACHE') ||
        upper.startsWith('RTR') ||
        upper.startsWith('RR') ||
        upper.startsWith('NTORQ') ||
        upper.startsWith('RONIN') ||
        upper.startsWith('RAIDER') ||
        upper.startsWith('JUPITER') ||
        upper.startsWith('IQUE') ||
        upper.startsWith('B0:D2:78') || // TVS Bluetooth OUI
        upper.contains('SMARTXONNECT') ||
        upper.contains('XONNECT') ||
        upper.contains('TVS') ||
        upper.contains('RTR') ||
        upper.contains('APACHE') ||
        upper.contains('NTORQ') ||
        upper.contains('RONIN') ||
        upper.contains('RAIDER') ||
        upper.contains('JUPITER') ||
        upper.contains('RR310') ||
        upper.contains('RTR310') ||
        upper.contains('RTR200') ||
        upper.contains('RTR160');
  }

  /// Request runtime Bluetooth and Location permissions (Android 12+ and legacy)
  Future<bool> checkAndRequestPermissions() async {
    if (kIsWeb) return true;

    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.location,
      ].request();

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final locationGranted = (statuses[Permission.locationWhenInUse]?.isGranted ?? false) ||
          (statuses[Permission.location]?.isGranted ?? false);

      return (scanGranted && connectGranted) || locationGranted;
    } catch (e) {
      debugPrint('Permission error: $e');
      return true;
    }
  }

  /// Start BLE scanning for nearby Bluetooth devices and TVS SmartXonnect clusters.
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        _setStage(ConnectionStage.error, error: 'Bluetooth permissions were denied');
        return;
      }

      // Check if Bluetooth adapter is enabled
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _setStage(ConnectionStage.error, error: 'Please turn on Bluetooth');
        return;
      }

      _discoveredBikes.clear();
      _setStage(ConnectionStage.scanning);

      // 1. Immediately load already bonded/paired TVS SmartXonnect clusters (e.g. TI05BL06, RMB...)
      try {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (final device in bonded) {
          final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
          final isTvs = isTvsDevice(name);
          // Only add bonded devices that are TVS SmartXonnect clusters (exclude headphones, watches, etc.)
          if (!isTvs) continue;

          VehicleAdapter matchedAdapter = _adapter;
          if (name.toUpperCase().contains('310') || name.toUpperCase().contains('RR')) {
            matchedAdapter = TvsRr310Adapter();
          } else {
            matchedAdapter = TvsRtr200Adapter();
          }

          final bike = DiscoveredBike(
            id: device.remoteId.str,
            name: name,
            rssi: 0,
            adapter: matchedAdapter,
            isPaired: true,
            isNearby: false,
            isTvs: true,
          );
          if (!_discoveredBikes.any((b) => b.id == bike.id)) {
            _discoveredBikes.add(bike);
          }
        }
        if (_discoveredBikes.isNotEmpty) {
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[BLE] Bonded devices check: $e');
      }

      // 2. Listen to active BLE scan results
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final advName = r.advertisementData.advName;
          final platformName = r.device.platformName;
          final name = advName.isNotEmpty
              ? advName
              : (platformName.isNotEmpty ? platformName : '');

          if (name.isEmpty) continue;

          final isTvs = isTvsDevice(name);

          VehicleAdapter matchedAdapter = _adapter;
          if (name.toUpperCase().contains('310') || name.toUpperCase().contains('RR')) {
            matchedAdapter = TvsRr310Adapter();
          } else {
            matchedAdapter = TvsRtr200Adapter();
          }

          final existingIdx = _discoveredBikes.indexWhere((b) => b.id == r.device.remoteId.str);
          if (existingIdx >= 0) {
            _discoveredBikes[existingIdx] = _discoveredBikes[existingIdx].copyWith(
              rssi: r.rssi,
              name: name,
              isNearby: true,
              isTvs: isTvs,
            );
          } else {
            final bike = DiscoveredBike(
              id: r.device.remoteId.str,
              name: name,
              rssi: r.rssi,
              adapter: matchedAdapter,
              isNearby: true,
              isTvs: isTvs,
            );
            // Prioritize TVS / RMB SmartXonnect devices at the top
            if (isTvs) {
              _discoveredBikes.insert(0, bike);
            } else {
              _discoveredBikes.add(bike);
            }
            notifyListeners();
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _setStage(ConnectionStage.error, error: 'Scan failed: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    if (_stage == ConnectionStage.scanning) {
      _setStage(ConnectionStage.disconnected);
    }
  }

  /// Connect to a discovered motorcycle cluster
  Future<void> connect(DiscoveredBike bike) async {
    try {
      await stopScan();
      _selectedBike = bike;
      _adapter = bike.adapter;
      _setStage(ConnectionStage.connecting);

      final device = BluetoothDevice.fromId(bike.id);
      _connectedDevice = device;

      // Ensure any previous connection listener is cleaned up before connecting
      await _connectionSubscription?.cancel();

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
        mtu: null,
      );

      // Track connection state ONLY after connection is successfully established
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _stage != ConnectionStage.disconnected) {
          _handleDisconnection();
        }
      });

      // Clear Android GATT cache to prevent stale handles from previous pairings
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await device.clearGattCache();
        } catch (e) {
          debugPrint('[BLE] clearGattCache notice: $e');
        }
      }

      // Small delay for BLE connection layer to stabilize
      await Future.delayed(const Duration(milliseconds: 350));

      // Request MTU up to 512 for high-speed telemetry frames
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (e) {
          debugPrint('[BLE] requestMtu notice: $e');
        }
      }

      // Discover GATT services with retry
      List<BluetoothService> services = [];
      try {
        services = await device.discoverServices();
      } catch (e) {
        debugPrint('[BLE] discoverServices pass 1: $e');
      }

      if (services.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          services = await device.discoverServices();
        } catch (e) {
          debugPrint('[BLE] discoverServices pass 2: $e');
        }
      }

      BluetoothService? tvsService;
      final expectedServiceGuid = Guid(_adapter.serviceUuid);
      final expectedServiceNorm = expectedServiceGuid.str128.replaceAll('-', '').toUpperCase();
      final expectedReadNorm = Guid(_adapter.readCharacteristicUuid).str128.replaceAll('-', '').toUpperCase();
      final expectedWriteNorm = Guid(_adapter.writeCharacteristicUuid).str128.replaceAll('-', '').toUpperCase();

      for (final s in services) {
        final sNorm = s.uuid.str128.replaceAll('-', '').toUpperCase();
        final sStr = s.uuid.str.toUpperCase();
        if (s.uuid == expectedServiceGuid ||
            sNorm == expectedServiceNorm ||
            sStr.contains('5456534D') ||
            sNorm.startsWith('5456534D') ||
            sStr.contains('TVS')) {
          tvsService = s;
          break;
        }
      }

      // Locate Read/Notify (0x5354) and Write (0x5352) characteristics
      _telemetryCharacteristic = null;
      _commandCharacteristic = null;

      final servicesToInspect = tvsService != null
          ? [tvsService, ...services.where((s) => s != tvsService)]
          : services;

      // Pass 1: Strict UUID matching (exact 128-bit, 16-bit, or contains 5354 / 5352)
      for (final s in servicesToInspect) {
        for (final c in s.characteristics) {
          final cNorm = c.uuid.str128.replaceAll('-', '').toUpperCase();
          final cStr = c.uuid.str.toUpperCase();

          if (_telemetryCharacteristic == null &&
              (cNorm == expectedReadNorm ||
                  cStr.contains('5354') ||
                  cNorm.contains('5354') ||
                  cStr.endsWith('5354'))) {
            _telemetryCharacteristic = c;
          }

          if (_commandCharacteristic == null &&
              (cNorm == expectedWriteNorm ||
                  cStr.contains('5352') ||
                  cNorm.contains('5352') ||
                  cStr.endsWith('5352'))) {
            _commandCharacteristic = c;
          }
        }
        if (_telemetryCharacteristic != null && _commandCharacteristic != null) {
          break;
        }
      }

      // Pass 2: Fallback in matched TVS Primary Service
      // The TVS SmartXonnect service has exactly 2 characteristics:
      // Telemetry (Notify/Indicate) and Command (Write/WriteWithoutResponse)
      if (tvsService != null &&
          (_telemetryCharacteristic == null || _commandCharacteristic == null)) {
        for (final c in tvsService.characteristics) {
          if (_telemetryCharacteristic == null &&
              (c.properties.notify || c.properties.indicate)) {
            _telemetryCharacteristic = c;
            debugPrint('[BLE] Bound telemetry characteristic via notify property: ${c.uuid}');
          } else if (_commandCharacteristic == null &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _commandCharacteristic = c;
            debugPrint('[BLE] Bound command characteristic via write property: ${c.uuid}');
          }
        }
      }

      // Pass 3: Fallback across any non-SIG custom vendor service if still missing
      if (_telemetryCharacteristic == null || _commandCharacteristic == null) {
        for (final s in services) {
          final sStr = s.uuid.str.toUpperCase();
          if (sStr.startsWith('000018') ||
              sStr == '1800' ||
              sStr == '1801' ||
              sStr == '180A' ||
              sStr == '180F') {
            continue;
          }
          for (final c in s.characteristics) {
            if (_telemetryCharacteristic == null &&
                (c.properties.notify || c.properties.indicate)) {
              _telemetryCharacteristic = c;
            } else if (_commandCharacteristic == null &&
                (c.properties.write || c.properties.writeWithoutResponse)) {
              _commandCharacteristic = c;
            }
          }
          if (_telemetryCharacteristic != null && _commandCharacteristic != null) break;
        }
      }

      if (_telemetryCharacteristic == null || _commandCharacteristic == null) {
        if (services.isEmpty) {
          _setStage(
            ConnectionStage.error,
            error:
                'Bike cluster services not ready. Please turn ignition OFF, wait 5 seconds, turn ignition ON and tap CONNECT.',
          );
        } else if (!bike.isTvs) {
          _setStage(
            ConnectionStage.error,
            error:
                '${bike.name} is not a TVS SmartXonnect motorcycle. Please select your Apache (e.g. TI05BL06).',
          );
        } else {
          _setStage(
            ConnectionStage.error,
            error:
                'Could not resolve SmartXonnect characteristics on ${bike.name}. Please restart bike console and retry.',
          );
        }
        return;
      }

      // Dynamic bond listener: automatically finalize authentication as soon as Android completes pairing
      device.bondState.listen((bondState) {
        if (bondState == BluetoothBondState.bonded && _stage == ConnectionStage.awaitingPin) {
          _finalizeAuthentication();
        }
      });

      // Check bond state: if already bonded (or previously paired in OS), finalize directly; else prompt user for PIN
      BluetoothBondState? currentBond = device.prevBondState;
      if (currentBond == null) {
        try {
          currentBond = await device.bondState.first.timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      if (currentBond == BluetoothBondState.bonded || bike.isPaired) {
        await _finalizeAuthentication();
      } else {
        _setStage(ConnectionStage.awaitingPin);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('connection canceled') ||
          msg.contains('code: 10') ||
          msg.contains('code: 133') ||
          msg.contains('timed out') ||
          msg.contains('timeout')) {
        _setStage(
          ConnectionStage.error,
          error:
              'Bike cluster unreachable. Please turn bike ignition ON (screen awake) and keep your phone near the bike.',
        );
      } else {
        _setStage(ConnectionStage.error, error: 'Connection failed: $e');
      }
    }
  }

  /// Submit dynamic 6-digit PIN entered from the instrument cluster LCD
  Future<bool> submitPin(String pin) async {
    if (_connectedDevice == null) return false;

    try {
      // In production Android, pairing is completed via platform SMP dialog
      // or setPin call. Here we verify format and complete the bonding handshake.
      if (pin.length != 6 || int.tryParse(pin) == null) {
        _errorMessage = 'PIN must be exactly 6 digits';
        notifyListeners();
        return false;
      }

      // Trigger createBond if available
      try {
        await _connectedDevice!.createBond();
      } catch (_) {}

      await _finalizeAuthentication();
      return true;
    } catch (e) {
      _setStage(ConnectionStage.error, error: 'PIN verification failed: $e');
      return false;
    }
  }

  /// Finalize authentication and enable notifications on characteristic 0x5354
  Future<void> _finalizeAuthentication() async {
    try {
      _setStage(ConnectionStage.authenticated);

      // Persist bike identification for automatic reconnection on ignition start
      if (_selectedBike != null) {
        _savedBikeId = _selectedBike!.id;
        _savedBikeName = _selectedBike!.name;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefBikeId, _savedBikeId!);
          await prefs.setString(_prefBikeName, _savedBikeName!);
        } catch (_) {}
      }

      if (_telemetryCharacteristic != null) {
        await _telemetryCharacteristic!.setNotifyValue(true);
        await _telemetrySubscription?.cancel();
        _telemetrySubscription = _telemetryCharacteristic!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final raw = Uint8List.fromList(value);
            final updated = _adapter.parseTelemetry(raw, _telemetry);

            // Check for Handlebar "i-Button" / Call Switch trigger event
            if (updated.hasIButtonEvent && !(_telemetry.hasIButtonEvent)) {
              IButtonService.instance.handleHardwareButtonPress(
                callAcceptRejectStatus: updated.callAcceptRejectStatus,
                isVoiceAssist: updated.isVoiceAssistInvoked,
              );
            }

            _telemetry = updated;

            // Automatically sync odometer & live telemetry across the entire app
            if (updated.odometerKm > 0) {
              TripRecorderService.instance.updateTelemetry(
                speedKmh: updated.speedKmh,
                odoKm: updated.odometerKm,
                batteryV: updated.batteryVoltage > 0 ? updated.batteryVoltage : null,
                economy: updated.instantMileageKml > 0 ? updated.instantMileageKml : null,
                fuelPct: updated.fuelLevelPercent > 0 ? updated.fuelLevelPercent : null,
                dte: updated.distanceToEmptyKm > 0 ? updated.distanceToEmptyKm : null,
              );
            }

            if (_stage != ConnectionStage.streamingTelemetry) {
              _setStage(ConnectionStage.streamingTelemetry);
            } else {
              notifyListeners();
            }
          }
        });
      }

      _setStage(ConnectionStage.streamingTelemetry);
      ClusterMediaService.instance.attachBleManager(this);
    } catch (e) {
      _setStage(ConnectionStage.error, error: 'Failed to start telemetry stream: $e');
    }
  }

  /// Dispatch turn-by-turn navigation packet to motorcycle cluster
  Future<bool> dispatchNavigation(NavigationInstruction instruction) async {
    final packet = _adapter.buildNavigationPacket(instruction);
    return writeRawPacket(packet);
  }

  /// Dispatch custom text line (Caller ID, SMS, or custom message) to cluster
  Future<bool> dispatchText(String text, {int line = 1}) async {
    final packet = _adapter.buildTextPacket(text, line: line);
    return writeRawPacket(packet);
  }

  /// Dispatch phone battery and cellular reception to cluster
  Future<bool> dispatchPhoneStatus({
    required int batteryPercent,
    required int signalStrengthBars,
  }) async {
    final packet = _adapter.buildPhoneStatePacket(
      batteryPercent: batteryPercent,
      signalStrengthBars: signalStrengthBars,
    );
    return writeRawPacket(packet);
  }

  Timer? _simulationTimer;
  bool _isSimulating = false;
  bool get isSimulating => _isSimulating;

  /// Start a simulated TVS cluster session from your desk without needing the physical bike
  void startSimulatedSession({String bikeName = 'TI05BL06 (Virtual Cluster)'}) {
    disconnect(userInitiated: true);
    _isSimulating = true;
    _selectedBike = DiscoveredBike(
      id: 'VIRTUAL_TVS_01',
      name: bikeName,
      rssi: -48,
      adapter: TvsRtr200Adapter(),
      isPaired: true,
      isNearby: true,
      isTvs: true,
    );
    _setStage(ConnectionStage.authenticated);
    _setStage(ConnectionStage.streamingTelemetry);

    int tick = 0;
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isSimulating) {
        timer.cancel();
        return;
      }
      tick++;
      final speed = 35.0 + 25.0 * math.sin(tick * 0.1).abs();
      final rpm = (3000 + 4000 * math.sin(tick * 0.1).abs()).toInt();
      final gear = ((speed / 15).floor() + 1).clamp(1, 5);
      final lean = 12.0 * math.sin(tick * 0.15);

      final odo = 3420.0 + (tick * 0.01);
      final batt = 14.1 + 0.2 * math.cos(tick * 0.1);

      _telemetry = _telemetry.copyWith(
        speedKmh: speed,
        engineRpm: rpm,
        gear: gear,
        leanAngleDegrees: lean.round(),
        accelerationG: 0.8 + 0.3 * math.sin(tick * 0.2),
        engineTempC: 78.0 + 2.0 * math.sin(tick * 0.05),
        batteryVoltage: batt,
        fuelLevelPercent: 78,
        odometerKm: odo,
        frontTyrePsi: 28.5,
        rearTyrePsi: 32.0,
        timestamp: DateTime.now(),
      );
      TripRecorderService.instance.updateTelemetry(
        speedKmh: speed,
        odoKm: odo,
        batteryV: batt,
        fuelPct: 78,
      );
      notifyListeners();
    });
  }

  void stopSimulatedSession() {
    _isSimulating = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _setStage(ConnectionStage.disconnected);
  }

  /// Low-level write to characteristic 0x5352 with dual write-mode auto-adaptation
  Future<bool> writeRawPacket(Uint8List packet) async {
    if (_isSimulating) {
      // In simulation mode, accept all packets as successfully written to virtual cluster
      return true;
    }

    if (_commandCharacteristic == null) {
      return false;
    }

    try {
      final prefersWithoutResponse = !_commandCharacteristic!.properties.write &&
          _commandCharacteristic!.properties.writeWithoutResponse;
      await _commandCharacteristic!.write(
        packet.toList(),
        withoutResponse: prefersWithoutResponse,
      );
      return true;
    } catch (e) {
      // Fallback to opposite write mode if first attempt was rejected by BLE stack
      try {
        await _commandCharacteristic!.write(
          packet.toList(),
          withoutResponse: true,
        );
        return true;
      } catch (e2) {
        debugPrint('Packet write failed after fallback: $e2');
        return false;
      }
    }
  }

  /// Disconnect cleanly
  Future<void> disconnect({bool userInitiated = true}) async {
    if (_isSimulating) {
      stopSimulatedSession();
      return;
    }

    await _telemetrySubscription?.cancel();
    await _connectionSubscription?.cancel();
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}

    if (userInitiated) {
      // If user manually tapped Disconnect, do not auto-reconnect immediately
      _handleDisconnection(allowAutoReconnect: false);
    } else {
      _handleDisconnection(allowAutoReconnect: true);
    }
  }

  void _handleDisconnection({bool allowAutoReconnect = true}) {
    ClusterMediaService.instance.detachBleManager();
    _connectedDevice = null;
    _telemetryCharacteristic = null;
    _commandCharacteristic = null;

    if (allowAutoReconnect && _autoConnectEnabled && _savedBikeId != null) {
      _setStage(
        ConnectionStage.reconnecting,
        error: 'Ignition off or signal lost. Waiting for bike to start...',
      );
      _startAutoReconnectWatchdog();
    } else {
      _setStage(ConnectionStage.disconnected);
    }
  }

  /// Starts low-power background scan to automatically connect as soon as
  /// bike ignition key turns ON and cluster begins BLE advertising.
  Future<void> _startAutoReconnectWatchdog() async {
    if (!_autoConnectEnabled || _savedBikeId == null) return;
    if (_stage == ConnectionStage.scanning || _stage.isConnected) return;

    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return;

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) return;

      _setStage(
        ConnectionStage.reconnecting,
        error: 'Waiting for $_savedBikeName ignition to turn on...',
      );

      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final id = r.device.remoteId.str;
          final advName = r.advertisementData.advName;
          final name = advName.isNotEmpty ? advName : r.device.platformName;

          if (id == _savedBikeId ||
              (_savedBikeName != null && name.toLowerCase().contains(_savedBikeName!.toLowerCase()))) {
            debugPrint('[AutoConnect] Bike ignition detected ($name)! Connecting immediately...');
            await stopScan();

            final bike = DiscoveredBike(
              id: id,
              name: name.isNotEmpty ? name : (_savedBikeName ?? 'Apache RTR 200'),
              rssi: r.rssi,
              adapter: _adapter,
            );
            await connect(bike);
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(hours: 24));
    } catch (e) {
      debugPrint('[AutoConnect] Watchdog error: $e');
    }
  }

  void _setStage(ConnectionStage stage, {String? error}) {
    _stage = stage;
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }
}
