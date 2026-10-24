import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../media/cluster_media_service.dart';
import 'lcd_cluster_simulator.dart';

/// Cinematic "MOTOLINK LINK CONNECTED" entrance animation overlay
/// featuring rotating HUD cyber rings, logo 3D bounce scale,
/// holographic telemetry status, and cluster ribbon greeting dispatch.
class MotoLinkConnectedOverlay extends StatefulWidget {
  final String bikeName;
  final VoidCallback? onDismissed;

  const MotoLinkConnectedOverlay({
    super.key,
    this.bikeName = 'TVS APACHE RTR 200 4V',
    this.onDismissed,
  });

  /// Static helper to trigger the animation anywhere in the app
  static Future<void> show(BuildContext context, {String bikeName = 'TVS APACHE RTR 200 4V'}) {
    // Also dispatch welcome greeting to motorcycle cluster LCD ribbon
    ClusterMediaService.instance.updateMedia(
      trackTitle: 'LINK CONNECTED',
      artist: 'TVS RACING',
      isPlaying: true,
    );

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return MotoLinkConnectedOverlay(
          bikeName: bikeName,
          onDismissed: () => Navigator.of(context, rootNavigator: true).pop(),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  State<MotoLinkConnectedOverlay> createState() => _MotoLinkConnectedOverlayState();
}

class _MotoLinkConnectedOverlayState extends State<MotoLinkConnectedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final AnimationController _radarController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _textSlideAnimation;
  late final Animation<double> _badgeSlideAnimation;
  late final Animation<double> _sweepAngleAnimation;

  @override
  void initState() {
    super.initState();

    // Trigger haptic vibration on phone to match bike ignition connection
    HapticFeedback.heavyImpact();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // 1. Scale with snappy elastic bounce
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    // 2. Fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 3. Tachometer Sweep Arc (0 to 360 deg)
    _sweepAngleAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.8, curve: Curves.easeInOutCubic),
      ),
    );

    // 4. Headline Slide up
    _textSlideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Specs & Badges Slide up
    _badgeSlideAnimation = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();

    // Auto-dismiss after 3.2 seconds
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    const cyan = Color(0xFF00E5FF);
    const crimson = Color(0xFFE53935);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismissed,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Radial Background Glow
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final pulse = _pulseController.value;
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85 + (pulse * 0.15),
                      colors: [
                        crimson.withOpacity(0.22 + (pulse * 0.08)),
                        gold.withOpacity(0.12),
                        Colors.black.withOpacity(0.92),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Animated Rotating Tachometer / Cyber Rings
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, _) {
                final rot = _radarController.value * 2 * math.pi;
                return Transform.rotate(
                  angle: rot,
                  child: CustomPaint(
                    size: const Size(320, 320),
                    painter: _CyberRingsPainter(
                      goldColor: gold,
                      cyanColor: cyan,
                      sweepAngle: _sweepAngleAnimation.value,
                    ),
                  ),
                );
              },
            ),

            // Central Core Content Card
            AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. MOTOLINK 3D Floating Logo Showcase
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF1E232F),
                          Color(0xFF0B0E14),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.45),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: cyan.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: gold.withOpacity(0.8),
                        width: 2.2,
                      ),
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 2. Animated MOTOLINK LINK CONNECTED Title
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlideAnimation.value),
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFD54F),
                              Color(0xFFFFFFFF),
                              Color(0xFFFFB300),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'MOTOLINK LINK CONNECTED',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFB300),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle Badge: TVS SmartXonnect Linked
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: gold.withOpacity(0.65),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withOpacity(0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00E676),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF00E676),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '• TVS SMARTXONNECT LINKED •',
                                style: TextStyle(
                                  color: Color(0xFFE5A93C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 3. Telemetry Specs Pill Row
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _badgeSlideAnimation.value),
                        child: child,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141922).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.two_wheeler, 'BIKE', widget.bikeName.split(' ').take(2).join(' ')),
                          Container(width: 1, height: 26, color: Colors.white12),
                          _buildStatItem(Icons.network_cell, '5G LINK', '5 BARS'),
                          Container(width: 1, height: 26, color: Colors.white12),
                          _buildStatItem(Icons.speed, 'TELEMETRY', 'LIVE 10Hz'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Watch Bike LCD Cluster Animation Button
                  InkWell(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      LcdClusterSimulator.show(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed, color: Color(0xFF00E5FF), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'WATCH BIKE LCD CLUSTER ANIMATION',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tap to skip hint
                  Text(
                    'Tap anywhere to continue',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFE5A93C), size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for glowing circular cyber rings & tachometer sweep arc
class _CyberRingsPainter extends CustomPainter {
  final Color goldColor;
  final Color cyanColor;
  final double sweepAngle;

  _CyberRingsPainter({
    required this.goldColor,
    required this.cyanColor,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer dashed boundary ring
    final dashPaint = Paint()
      ..color = goldColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 8, dashPaint);

    // 2. Cyan tachometer sweep arc
    final sweepPaint = Paint()
      ..color = cyanColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 20),
      -math.pi / 2,
      sweepAngle,
      false,
      sweepPaint,
    );

    // 3. Inner tick marks
    final tickPaint = Paint()
      ..color = goldColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const tickCount = 24;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i * 2 * math.pi) / tickCount;
      final start = Offset(
        center.dx + (radius - 32) * math.cos(angle),
        center.dy + (radius - 32) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 24) * math.cos(angle),
        center.dy + (radius - 24) * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberRingsPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}
