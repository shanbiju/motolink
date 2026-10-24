import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_models.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_colors.dart';
import '../parking/last_parked_view.dart';
import '../rides/my_rides_view.dart';
import '../telemetry/lcd_cluster_simulator.dart';
import '../telemetry/motolink_connected_overlay.dart';
import '../telemetry/trip_recorder_service.dart';

class GarageHomeView extends ConsumerWidget {
  final VoidCallback onOpenPairing;
  final VoidCallback onOpenCockpit;

  const GarageHomeView({
    super.key,
    required this.onOpenPairing,
    required this.onOpenCockpit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleManager = ref.watch(bleManagerProvider);
    final telemetry = ref.watch(telemetryProvider);
    final isConnected = bleManager.stage.isConnected;

    final fuelPct = telemetry.fuelLevelPercent > 0 ? telemetry.fuelLevelPercent : 60;
    final odoKm = telemetry.odometerKm > 0 ? telemetry.odometerKm : TripRecorderService.instance.odometerKm;
    final speed = telemetry.speedKmh.round();
    final topSpeed = telemetry.topSpeedKmh > 0 ? telemetry.topSpeedKmh.round() : 99;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'MOTOLINK • RTR 200',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.8,
                  color: AppColors.textLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Connection Status Pill
          InkWell(
            onTap: onOpenPairing,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.accent.withOpacity(0.18)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isConnected ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? AppColors.accent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Connected' : 'Scan Bike',
                    style: TextStyle(
                      color: isConnected ? AppColors.accent : AppColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TVS Racing RTR 200 Hero Header Banner (Screenshot 4)
            _buildRacingHeaderCard(topSpeed),
            const SizedBox(height: 16),

            // 2. Motorcycle Silhouette & Live Status Showcase
            _buildBikeShowcaseCard(context, isConnected, speed),
            const SizedBox(height: 16),

            // 3. 4 Quick Action Buttons (My Rides, Ride Details, Last Parked, Cockpit)
            _buildQuickActionsGrid(context),
            const SizedBox(height: 16),

            // 4. Live Bike Health Grid (Screenshot 2: Fuel 60%, Odo 3098 km, Range 109 km, Service OK)
            _buildBikeMetricsGrid(fuelPct, odoKm),
            const SizedBox(height: 16),

            // 5. Last Parked Strip (Screenshot 2: 19h ago • 847m away)
            _buildLastParkedStrip(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRacingHeaderCard(int topSpeed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B1818), Color(0xFFC62828), Color(0xFF1E232F)],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text(
                      'TVS Racing',
                      style: TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RTR 200 4V',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Rides', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      SizedBox(height: 2),
                      Text('3', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      SizedBox(height: 2),
                      Text('61.7 km', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top Speed', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('$topSpeed km/h', style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBikeShowcaseCard(BuildContext context, bool isConnected, int liveSpeed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APACHE RTR 200 4V',
                    style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'SmartXonnect Bluetooth Cluster Active',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$liveSpeed KM/H',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Bike Silhouette Icon Banner with Interactive Tap & Preview
          InkWell(
            onTap: () {
              MotoLinkConnectedOverlay.show(
                context,
                bikeName: isConnected ? 'TVS APACHE RTR 200 4V' : 'MOTOLINK RACING',
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.two_wheeler,
                    size: 90,
                    color: AppColors.accent.withOpacity(0.7),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            LcdClusterSimulator.show(context);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.7)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed, color: Color(0xFF00E5FF), size: 11),
                                SizedBox(width: 3),
                                Text(
                                  'BIKE LCD CLUSTER',
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            MotoLinkConnectedOverlay.show(
                              context,
                              bikeName: isConnected ? 'TVS APACHE RTR 200 4V' : 'MOTOLINK RACING',
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline, color: AppColors.accent, size: 11),
                                SizedBox(width: 3),
                                Text(
                                  'PHONE HUD',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 8.5,
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
                  ),
                  Positioned(
                    bottom: 8,
                    child: Text(
                      isConnected ? 'RIDE MODE ACTIVE • TAP TO REPLAY ANIMATION' : 'IGNITION OFF • TAP TO PREVIEW LINK ANIMATION',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Row(
      children: [
        _buildActionTile(
          context,
          icon: Icons.alt_route,
          title: 'My Rides',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRidesView()));
          },
        ),
        const SizedBox(width: 10),
        _buildActionTile(
          context,
          icon: Icons.analytics_outlined,
          title: 'Ride Details',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRidesView()));
          },
        ),
        const SizedBox(width: 10),
        _buildActionTile(
          context,
          icon: Icons.location_on_outlined,
          title: 'Last Parked',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LastParkedView()));
          },
        ),
        const SizedBox(width: 10),
        _buildActionTile(
          context,
          icon: Icons.speed,
          title: 'Cockpit',
          onTap: onOpenCockpit,
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accent, size: 24),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBikeMetricsGrid(int fuelPct, double odoKm) {
    return Column(
      children: [
        Row(
          children: [
            // Fuel Level Card
            Expanded(
              child: _buildInfoCard(
                icon: Icons.local_gas_station,
                title: '$fuelPct%',
                subtitle: 'Fuel Level',
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            // Odometer Card
            Expanded(
              child: _buildInfoCard(
                icon: Icons.speed,
                title: '${odoKm.toStringAsFixed(1)} km',
                subtitle: 'Odometer',
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Range
            Expanded(
              child: _buildInfoCard(
                icon: Icons.alt_route,
                title: '109 km',
                subtitle: 'Est. Range',
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            // Avg Economy
            Expanded(
              child: _buildInfoCard(
                icon: Icons.trending_up,
                title: '46 km/L',
                subtitle: 'Avg Economy',
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(width: 12),
            // Service Status
            Expanded(
              child: _buildInfoCard(
                icon: Icons.build_outlined,
                title: 'OK',
                subtitle: 'Service',
                color: Colors.greenAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLastParkedStrip(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LastParkedView()));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Parked Location',
                    style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '19h ago • 847m away • Kanakamala',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
