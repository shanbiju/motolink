import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_models.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_colors.dart';
import '../ibutton/ibutton_service.dart';
import '../media/cluster_media_card.dart';
import 'telemetry_models.dart';

class TelemetryDashboard extends ConsumerWidget {
  const TelemetryDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleManager = ref.watch(bleManagerProvider);
    final telemetry = ref.watch(telemetryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 14,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'MOTOLINK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent, width: 1),
            ),
            child: Center(
              child: Text(
                telemetry.rideMode.displayName,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Disconnect',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.link_off, color: AppColors.textMuted, size: 20),
            onPressed: () => bleManager.disconnect(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Vehicle Connection & Status Header Banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: bleManager.stage.isConnected ? AppColors.accent : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bleManager.selectedBike?.name ?? 'Apache RTR 200 4V',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bleManager.stage.displayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Side Stand Critical Warning Banner
            if (telemetry.isSideStandDown)
              _buildCriticalWarningBanner('SIDE STAND DEPLOYED - SHIFT INTERLOCK ACTIVE'),

            // Handlebar i-Button Trigger Banner
            if (telemetry.hasIButtonEvent)
              _buildIButtonBanner(),

            // Primary Cockpit Gauge (Speed + Gear + RPM Bar)
            _buildCockpitHero(context, telemetry),
            const SizedBox(height: 16),

            // Dynamics Row: Lean Angle + Acceleration G
            Row(
              children: [
                Expanded(child: _buildLeanAngleCard(telemetry)),
                const SizedBox(width: 12),
                Expanded(child: _buildAccelerationCard(telemetry)),
              ],
            ),
            const SizedBox(height: 16),

            // Trip & Fuel Efficiency Metrics
            _buildTripMetricsCard(telemetry),
            const SizedBox(height: 16),

            // Engine & Electrical Health Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'ENGINE TEMP',
                    value: '${telemetry.engineTempC.toStringAsFixed(0)}°C',
                    icon: Icons.thermostat,
                    color: telemetry.engineTempC > 105 ? AppColors.error : AppColors.accent,
                    subtext: telemetry.engineTempC > 105 ? 'OVERHEATING' : 'OPTIMAL',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'BATTERY',
                    value: '${telemetry.batteryVoltage.toStringAsFixed(1)} V',
                    icon: Icons.battery_charging_full,
                    color: telemetry.batteryVoltage < 11.8 ? AppColors.error : AppColors.accent,
                    subtext: telemetry.batteryVoltage < 11.8 ? 'LOW VOLTAGE' : 'HEALTHY',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TPMS Card
            _buildTpmsCard(telemetry),
            const SizedBox(height: 16),

            // Cluster Now Playing & 5G Network Fix Card
            ClusterMediaCard(isConnected: bleManager.stage.isConnected),
            const SizedBox(height: 16),

            // Extended Telemetry Status Grid
            _buildVehicleSwitchesCard(telemetry),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalWarningBanner(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIButtonBanner() {
    final current = IButtonService.instance.currentAction;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.accentGlow,
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(current.icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HANDLEBAR "i-BUTTON" PRESSED',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Executed Action: ${current.title}',
                  style: const TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitHero(BuildContext context, TelemetryData data) {
    final rpmRatio = (data.engineRpm / 11000.0).clamp(0.0, 1.0);
    final isRedline = data.engineRpm >= 9000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRedline ? AppColors.error : AppColors.accent.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isRedline ? AppColors.error.withOpacity(0.2) : AppColors.accentGlow,
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // RPM Bar & Gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TACHOMETER',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                '${data.engineRpm} RPM',
                style: TextStyle(
                  color: isRedline ? AppColors.error : AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 14, color: AppColors.background),
                FractionallySizedBox(
                  widthFactor: rpmRatio,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isRedline
                            ? [AppColors.accent, AppColors.error]
                            : [AppColors.accent.withOpacity(0.7), AppColors.accent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Speed & Gear Center Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large Speedometer Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    data.speedKmh.toStringAsFixed(0),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),
                  const Text(
                    'KM / H',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),

              // Large Gear Indicator
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: data.isNeutral ? AppColors.accent : AppColors.accent.withOpacity(0.7),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.accentGlow,
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    data.gearDisplay,
                    style: TextStyle(
                      color: data.isNeutral ? AppColors.accent : AppColors.textLight,
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),

          // Speed Session Summary
          Row(
            children: [
              Expanded(child: _buildSubStat('TOP SPEED', '${data.topSpeedKmh.toStringAsFixed(0)} km/h')),
              Expanded(child: _buildSubStat('AVG SPEED', '${data.averageSpeedKmh.toStringAsFixed(0)} km/h')),
              Expanded(child: _buildSubStat('THROTTLE', '${data.throttlePercent}%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String val) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            style: const TextStyle(color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildLeanAngleCard(TelemetryData data) {
    final angle = data.leanAngleDegrees;
    final direction = angle > 0 ? 'RIGHT' : (angle < 0 ? 'LEFT' : 'LEVEL');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LEAN ANGLE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              Icon(Icons.screen_rotation, color: AppColors.accent, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${angle.abs()}°',
              style: const TextStyle(color: AppColors.textLight, fontSize: 36, fontWeight: FontWeight.w900),
            ),
          ),
          Center(
            child: Text(
              direction,
              style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          // Visual horizon tilt line
          Center(
            child: Transform.rotate(
              angle: (angle * pi / 180.0),
              child: Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccelerationCard(TelemetryData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('G-FORCE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              Icon(Icons.trending_up, color: AppColors.accent, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${data.accelerationG.toStringAsFixed(2)} G',
              style: const TextStyle(color: AppColors.textLight, fontSize: 32, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              data.zeroToSixtyMs > 0 ? '0-60: ${(data.zeroToSixtyMs / 1000.0).toStringAsFixed(2)}s' : '0-60 READY',
              style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (data.accelerationG.abs() / 1.5).clamp(0.0, 1.0),
              backgroundColor: AppColors.background,
              color: AppColors.accent,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripMetricsCard(TelemetryData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('TRIP & RANGE OVERVIEW', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          // 2x2 Grid with Expanded to eliminate the 84-pixel overflow
          Row(
            children: [
              Expanded(child: _buildTripStat('ODOMETER', '${data.odometerKm > 0 ? data.odometerKm.toStringAsFixed(0) : "8818"} km')),
              const SizedBox(width: 12),
              Expanded(child: _buildTripStat('TRIP DISTANCE', '${data.tripDistanceKm.toStringAsFixed(1)} km')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTripStat('AVG MILEAGE', '${data.averageMileageKml.toStringAsFixed(1)} km/L')),
              const SizedBox(width: 12),
              Expanded(child: _buildTripStat('EST. RANGE', '${data.distanceToEmptyKm} km')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(val, style: const TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: AppColors.textLight, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtext, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTpmsCard(TelemetryData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tire_repair, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('TYRE PRESSURE MONITOR (TPMS)', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FRONT TYRE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        '${data.frontTyrePsi?.toStringAsFixed(1) ?? '--'} PSI',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${data.frontTyreTempC ?? '--'}°C • ${data.frontTyreBattery ?? '--'}% Bat',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REAR TYRE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        '${data.rearTyrePsi?.toStringAsFixed(1) ?? '--'} PSI',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${data.rearTyreTempC ?? '--'}°C • ${data.rearTyreBattery ?? '--'}% Bat',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSwitchesCard(TelemetryData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HARDWARE SWITCHES & INTERLOCKS',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill('SIDE STAND', data.isSideStandDown ? 'DOWN' : 'UP', data.isSideStandDown),
              _buildStatusPill('CLUTCH', data.isClutchPulled ? 'PULLED' : 'RELEASED', data.isClutchPulled),
              _buildStatusPill('BRAKE', data.isBrakeActive ? 'ACTIVE' : 'OFF', data.isBrakeActive),
              _buildStatusPill('KILL SWITCH', data.isKillSwitchActive ? 'ENGAGED' : 'RUN', data.isKillSwitchActive),
              _buildStatusPill('ABS MIL', data.isAbsMilActive ? 'ALERT' : 'OK', data.isAbsMilActive),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String name, String status, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withOpacity(0.15) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AppColors.accent : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$name: ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Text(
            status,
            style: TextStyle(
              color: isActive ? AppColors.accent : AppColors.textLight,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
