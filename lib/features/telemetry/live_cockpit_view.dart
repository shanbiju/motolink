import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_models.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_colors.dart';
import '../media/cluster_media_card.dart';
import '../parking/last_parked_view.dart';
import '../settings/settings_view.dart';
import 'telemetry_dashboard.dart';
import 'telemetry_models.dart';
import 'trip_recorder_service.dart';

class LiveCockpitView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenFindMyVehicle;

  const LiveCockpitView({
    super.key,
    this.onOpenFindMyVehicle,
  });

  @override
  ConsumerState<LiveCockpitView> createState() => _LiveCockpitViewState();
}

class _LiveCockpitViewState extends ConsumerState<LiveCockpitView> {
  final _tripRecorder = TripRecorderService.instance;

  @override
  void initState() {
    super.initState();
    _tripRecorder.addListener(_onTripUpdate);
  }

  @override
  void dispose() {
    _tripRecorder.removeListener(_onTripUpdate);
    super.dispose();
  }

  void _onTripUpdate() {
    if (mounted) setState(() {});
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsView()),
    );
  }

  void _navigateToFindMyBike() {
    if (widget.onOpenFindMyVehicle != null) {
      widget.onOpenFindMyVehicle!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LastParkedView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = ref.watch(bleManagerProvider);
    final telemetry = ref.watch(telemetryProvider);

    // Sync live telemetry to trip recorder
    _tripRecorder.updateTelemetry(
      speedKmh: telemetry.speedKmh,
      odoKm: telemetry.odometerKm > 0 ? telemetry.odometerKm : 8817.6,
      batteryV: telemetry.batteryVoltage > 0 ? telemetry.batteryVoltage : 12.3,
      dte: telemetry.distanceToEmptyKm,
    );

    final isConnected = bleManager.stage.isConnected;
    final bikeName = bleManager.selectedBike?.name ?? 'Apache RTR 200';
    final macAddress = bleManager.selectedBike?.id ?? '48:23:35:40:95:3B';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFF64DFDF) : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'MOTOLINK LIVE',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textLight, size: 24),
            tooltip: 'Settings',
            onPressed: _navigateToSettings,
          ),
          IconButton(
            icon: const Icon(
              Icons.speed,
              color: AppColors.textLight,
              size: 24,
            ),
            tooltip: 'RTR 200 Race Cluster',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TelemetryDashboard()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle: Connected • MAC Address
            Text(
              isConnected ? 'Connected • $macAddress • $bikeName' : 'Ready to Connect • $bikeName',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            // Card 1: LIVE VELOCITY & FUEL GAUGE
            _buildVelocityHeroCard(telemetry, isConnected),
            const SizedBox(height: 18),

            // Card 2: BIKE STATUS (Odo, Mileage, Battery)
            _buildBikeStatusCard(telemetry),
            const SizedBox(height: 18),

            // Card 3: CLUSTER NOW PLAYING & 5G NETWORK STATUS
            ClusterMediaCard(isConnected: isConnected),
            const SizedBox(height: 20),

            // Quick Access Switch to RTR 200 Race Telemetry
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TelemetryDashboard()),
                  );
                },
                icon: const Icon(Icons.speed, size: 18),
                label: const Text(
                  'VIEW RTR 200 RACE CLUSTER (RPM & LEAN ANGLE)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVelocityHeroCard(TelemetryData data, bool isConnected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + LIVE VELOCITY + BLE LIVE Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.speed, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'LIVE VELOCITY',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC7F9FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radio_button_checked, color: Color(0xFF007788), size: 10),
                    SizedBox(width: 5),
                    Text(
                      '• BLE LIVE',
                      style: TextStyle(
                        color: Color(0xFF005566),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Speed display: "0 km/h"
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.speedKmh.toStringAsFixed(0),
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'km/h',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fuel bar blocks + DTE (Distance To Empty)
          Row(
            children: [
              const Icon(Icons.local_gas_station_outlined, color: AppColors.textLight, size: 20),
              const SizedBox(width: 10),
              // 6 Fuel Bar Blocks
              Expanded(
                child: Row(
                  children: List.generate(6, (index) {
                    final fuelPercent = _tripRecorder.fuelPercent;
                    final isFilled = index < ((fuelPercent / 100.0) * 6).ceil();
                    return Expanded(
                      child: Container(
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: isFilled ? AppColors.accent : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFilled ? AppColors.accent : AppColors.border,
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${data.distanceToEmptyKm} km DTE',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Find My Scooter / Bike Button (Matching black rounded button in screenshot)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
                foregroundColor: AppColors.textLight,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
              ),
              onPressed: _navigateToFindMyBike,
              child: const Text(
                'Find My Bike',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBikeStatusCard(TelemetryData data) {
    final batteryVolts = data.batteryVoltage > 0 ? data.batteryVoltage : 12.3;
    final isWeakBattery = batteryVolts < 12.4;
    final odoKm = data.odometerKm > 0 ? data.odometerKm : _tripRecorder.odometerKm;
    final mileage = data.instantMileageKml > 0 ? data.instantMileageKml : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Bike icon + BIKE STATUS + Odometer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.two_wheeler, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BIKE STATUS',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${odoKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Row 1: Mileage
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: AppColors.textLight, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mileage (Live & Avg)',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live: ${mileage.toStringAsFixed(0)} km/L • Avg: ${data.averageMileageKml.toStringAsFixed(1)} km/L',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Eco',
                  style: TextStyle(
                    color: Color(0xFF8A5A00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(color: AppColors.border, height: 1),
          ),

          // Row 2: Battery
          Row(
            children: [
              const Icon(Icons.battery_std, color: AppColors.textLight, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Battery',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${batteryVolts.toStringAsFixed(1)} V',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isWeakBattery ? const Color(0xFFFFF3D6) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isWeakBattery ? 'Weak' : 'Healthy',
                  style: TextStyle(
                    color: isWeakBattery ? const Color(0xFF8A5A00) : const Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
