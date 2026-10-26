import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_colors.dart';
import '../telemetry/trip_recorder_service.dart';
import 'my_rides_view.dart';

class RideTelemetryView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenFullTripLog;

  const RideTelemetryView({
    super.key,
    this.onOpenFullTripLog,
  });

  @override
  ConsumerState<RideTelemetryView> createState() => _RideTelemetryViewState();
}

class _RideTelemetryViewState extends ConsumerState<RideTelemetryView> {
  final _tripRecorder = TripRecorderService.instance;

  @override
  void initState() {
    super.initState();
    _tripRecorder.addListener(_onRecorderUpdate);
  }

  @override
  void dispose() {
    _tripRecorder.removeListener(_onRecorderUpdate);
    super.dispose();
  }

  void _onRecorderUpdate() {
    if (mounted) setState(() {});
  }

  void _navigateToFullLog() {
    if (widget.onOpenFullTripLog != null) {
      widget.onOpenFullTripLog!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MyRidesView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = ref.watch(bleManagerProvider);
    final telemetry = ref.watch(telemetryProvider);

    // Sync live telemetry to trip recorder via ref.listen to avoid side-effects in build
    ref.listen(telemetryProvider, (prev, next) {
      _tripRecorder.updateTelemetry(
        speedKmh: next.speedKmh,
        odoKm: next.odometerKm > 0 ? next.odometerKm : _tripRecorder.odometerKm,
        economy: next.instantMileageKml > 0 ? next.instantMileageKml : 53.0,
        batteryV: next.batteryVoltage > 0 ? next.batteryVoltage : 12.3,
      );
    });

    final bikeName = bleManager.selectedBike?.name ?? 'TVS';
    final isRecording = _tripRecorder.isRecording;
    final durationStr = isRecording ? _tripRecorder.formattedDuration : '7m';
    final fixesCount = isRecording ? _tripRecorder.gpsFixes : 1;
    final odoKm = _tripRecorder.odometerKm;
    final economyVal = _tripRecorder.economyKmL;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'MOTOLINK RIDES',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Pill: • LIVE • TVS
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFC7F9FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, color: Color(0xFF007788), size: 8),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE • ${bikeName.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF005566),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Card 1: RECORDING TRIP
            _buildRecordingTripCard(isRecording, durationStr, fixesCount),
            const SizedBox(height: 16),

            // Row 2: Grid of ODOMETER & ECONOMY
            Row(
              children: [
                // Left: Odometer
                Expanded(
                  child: _buildMetricBox(
                    icon: Icons.alt_route_rounded,
                    title: 'ODOMETER...',
                    value: '${odoKm.toStringAsFixed(1)}\nkm',
                  ),
                ),
                const SizedBox(width: 14),
                // Right: Economy
                Expanded(
                  child: _buildMetricBox(
                    icon: Icons.eco_outlined,
                    title: 'ECONOMY...',
                    value: '${economyVal.toStringAsFixed(0)} km/L',
                    subtext: 'Avg: ${telemetry.averageMileageKml.toStringAsFixed(1)} km/L',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 3: TRIP HISTORY
            _buildTripHistoryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingTripCard(bool isRecording, String durationStr, int fixesCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecording ? AppColors.accent : AppColors.border,
          width: isRecording ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Record Dot + RECORDING TRIP + Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isRecording ? Colors.redAccent : AppColors.textLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'RECORDING TRIP',
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
                durationStr,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Bottom Row: Fixes count + Stop/Start button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$fixesCount fixes',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () {
                  if (isRecording) {
                    _tripRecorder.stopRecording();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Trip recorded and saved to My Rides!'),
                        backgroundColor: AppColors.accent,
                      ),
                    );
                  } else {
                    _tripRecorder.startRecording();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    isRecording ? 'Stop' : 'Start',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required IconData icon,
    required String title,
    required String value,
    String? subtext,
  }) {
    return Container(
      height: 155,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (subtext != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryCard() {
    final tripCount = _tripRecorder.tripLogs.isNotEmpty ? _tripRecorder.tripLogs.length : 1;

    return InkWell(
      onTap: _navigateToFullLog,
      borderRadius: BorderRadius.circular(24),
      child: Container(
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
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'TRIP HISTORY',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$tripCount trip logged — tap for the full\nlog.',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
