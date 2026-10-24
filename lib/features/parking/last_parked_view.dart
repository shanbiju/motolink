import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class LastParkedView extends StatelessWidget {
  final String bikeName;
  final String dateStr;
  final String timeStr;
  final String addressCode;
  final double distanceKm;
  final double latitude;
  final double longitude;

  const LastParkedView({
    super.key,
    this.bikeName = 'APACHE RTR 200 4V',
    this.dateStr = '2026-10-21',
    this.timeStr = '18:40',
    this.addressCode = '985R+3GJ, Kanakamala, Kerala',
    this.distanceKm = 26.8,
    this.latitude = 10.3705,
    this.longitude = 76.2892,
  });

  Future<void> _launchDirections(BuildContext context) async {
    final nativeUri = Uri.parse('google.navigation:q=$latitude,$longitude&mode=2w');
    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=two-wheeler');

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open map navigation'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Navigation launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Find My Vehicle',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textLight),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Simulated Map Visual with Road Curves and Location Pin
          Positioned.fill(
            child: _buildMapCanvas(),
          ),

          // 2. Floating GPS Target Re-center Button
          Positioned(
            right: 20,
            bottom: 240,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.accent,
              shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
              onPressed: () {},
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),

          // 3. Parked Vehicle Detail Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: Parked Bike Name & Timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PARKED BIKE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bikeName,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),

                  // Row: Address & Distance Away
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LAST SEEN LOCATION',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addressCode,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'from current phone',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons: Share & Get Directions
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textLight,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Location shared: $addressCode ($latitude, $longitude)'),
                                backgroundColor: AppColors.accent,
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('SHARE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: () => _launchDirections(context),
                          icon: const Icon(Icons.directions, color: AppColors.background),
                          label: const Text(
                            'GET DIRECTIONS',
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCanvas() {
    return Container(
      color: const Color(0xFF161A22),
      child: CustomPaint(
        painter: _RoadMapPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.two_wheeler,
                  color: AppColors.background,
                  size: 28,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent, width: 1.5),
                ),
                child: const Text(
                  'APACHE PARKED HERE',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background terrain curves
    final terrainPaint = Paint()
      ..color = const Color(0xFF1E2530)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.2, size.width, size.height * 0.45)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, terrainPaint);

    // Primary Highway (Blue route line)
    final routePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.45,
        size.width * 0.4,
        size.height * 0.52,
        size.width * 0.5,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.6,
        size.height * 0.44,
        size.width * 0.8,
        size.height * 0.60,
        size.width,
        size.height * 0.68,
      );
    canvas.drawPath(routePath, routePaint);

    // Secondary Roads (Gridlines)
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.8, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.35),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
