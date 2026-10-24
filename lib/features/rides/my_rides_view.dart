import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ride_models.dart';

class MyRidesView extends StatefulWidget {
  const MyRidesView({super.key});

  @override
  State<MyRidesView> createState() => _MyRidesViewState();
}

class _MyRidesViewState extends State<MyRidesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<RideRecord> _rides = RideRecord.defaultRides();
  RideRecord? _selectedRide;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedRide = _rides.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Rides & Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textLight),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'RIDE LOGS'),
            Tab(text: 'LAST RIDE INFO'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: My Rides List
          _buildRidesListTab(),

          // Tab 2: Last Ride Information & HUD
          _buildLastRideInfoTab(_selectedRide ?? _rides.first),
        ],
      ),
    );
  }

  Widget _buildRidesListTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_rides.length} Rides Logged',
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.file_download_outlined, size: 16, color: AppColors.accent),
              label: const Text('Export GPX', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exported ride telemetry to GPX file'),
                    backgroundColor: AppColors.accent,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        ..._rides.map((ride) => _buildRideCard(ride)),
      ],
    );
  }

  Widget _buildRideCard(RideRecord ride) {
    final isSelected = _selectedRide?.id == ride.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.08),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header Row: Ride Title, Edit, Share, Delete
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ride.title,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                  onPressed: () {},
                  tooltip: 'Rename Ride',
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.accent),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Shared ${ride.title} (${ride.distanceKm} km, Top: ${ride.topSpeedKmh} km/h)'),
                        backgroundColor: AppColors.accent,
                      ),
                    );
                  },
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _rides.removeWhere((r) => r.id == ride.id);
                    });
                  },
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Metric Columns: Date | Distance | Duration
          InkWell(
            onTap: () {
              setState(() => _selectedRide = ride);
              _tabController.animateTo(1);
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATE',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ride.date,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DISTANCE',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ride.distanceKm} km',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DURATION',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ride.formattedDuration,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  Widget _buildLastRideInfoTab(RideRecord ride) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tour Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B1818), Color(0xFFC62828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Any plans for a tour?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {},
                  child: const Text('TOUR NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Central Cockpit HUD Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Circular Top Speed Gauge
                Center(
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(170, 170),
                          painter: _SpeedDialPainter(speed: ride.topSpeedKmh.toDouble(), maxSpeed: 150),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TOP SPEED',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ride.topSpeedKmh}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'km/h',
                              style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Grid 1: Distance & Best 0-60
                Row(
                  children: [
                    _buildMetricTile(
                      icon: Icons.alt_route,
                      label: 'DISTANCE',
                      value: '${ride.distanceKm} km',
                      valueColor: AppColors.textLight,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricTile(
                      icon: Icons.timer,
                      label: 'BEST 0-60',
                      value: '${ride.bestZeroToSixtySec} sec',
                      valueColor: AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Grid 2: Ride Time & Total Time
                Row(
                  children: [
                    _buildMetricTile(
                      icon: Icons.access_time,
                      label: 'RIDE TIME',
                      value: '01:29:40',
                      valueColor: AppColors.textLight,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricTile(
                      icon: Icons.calendar_today,
                      label: 'TOTAL TIME',
                      value: '13 Days',
                      valueColor: AppColors.textLight,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Grid 3: Altitude & Timing
                Row(
                  children: [
                    _buildMetricTile(
                      icon: Icons.terrain,
                      label: 'ALTITUDE',
                      value: '${ride.altitudeMeters} m',
                      valueColor: AppColors.textLight,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricTile(
                      icon: Icons.schedule,
                      label: 'START / END',
                      value: '${ride.startTime} - ${ride.endTime}',
                      valueColor: AppColors.textLight,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Grid 4: Max Lean Angle & Max G-Force
                Row(
                  children: [
                    _buildMetricTile(
                      icon: Icons.two_wheeler,
                      label: 'MAX LEAN ANGLE',
                      value: '${ride.maxLeanAngleDeg}°',
                      valueColor: AppColors.accent,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricTile(
                      icon: Icons.speed,
                      label: 'MAX G-FORCE',
                      value: '${ride.maxGForce}g',
                      valueColor: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Analyse CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Analyzing ride telemetry across 45 GPS datapoints for ${ride.title}'),
                    backgroundColor: AppColors.accent,
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined, color: AppColors.background),
              label: const Text(
                'ANALYSE RIDE TELEMETRY',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedDialPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;

  _SpeedDialPainter({required this.speed, required this.maxSpeed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5,
      false,
      trackPaint,
    );

    // Active speed arc
    final sweepAngle = (speed / maxSpeed).clamp(0.0, 1.0) * (pi * 1.5);
    final activePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedDialPainter oldDelegate) =>
      oldDelegate.speed != speed || oldDelegate.maxSpeed != maxSpeed;
}
