import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic TVS Apache RTR 200 4V White-Backlit Digital LCD Cluster Simulator.
/// Simulates the exact hardware behavior:
/// 1. Key-ON Tachometer bar sweep to 12,000 RPM & Speedometer 888 test
/// 2. Bluetooth handshake & 5G 5-bar reception icon
/// 3. Multi-frame connection greeting sequence on the 14-segment bottom ribbon
/// 4. Turn-by-Turn navigation assist and music track display
class LcdClusterSimulator extends StatefulWidget {
  final bool autoStartSequence;
  final VoidCallback? onClose;

  const LcdClusterSimulator({
    super.key,
    this.autoStartSequence = true,
    this.onClose,
  });

  /// Opens the interactive LCD simulator dialog anywhere
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: LcdClusterSimulator(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  State<LcdClusterSimulator> createState() => _LcdClusterSimulatorState();
}

enum LcdDisplayMode { connectionAnim, navigationTbt, musicTrack, raceTelemetry }

class _LcdClusterSimulatorState extends State<LcdClusterSimulator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // Cluster Simulation State
  int _rpm = 0;
  int _speed = 0;
  int _gear = 0; // 0 = Neutral, 1-5
  int _fuelBars = 5;
  bool _shiftLightOn = false;
  bool _btConnected = false;
  int _signalBars = 5;
  String _ribbonText = '                ';
  int _tbtDistance = 250;
  LcdDisplayMode _mode = LcdDisplayMode.connectionAnim;

  Timer? _sequenceTimer;
  int _sequenceStep = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (widget.autoStartSequence) {
      _startIgnitionAndConnectionSequence();
    }
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Plays the exact Ignition Key-ON + Bluetooth Connection sequence
  void _startIgnitionAndConnectionSequence() {
    _sequenceTimer?.cancel();
    _mode = LcdDisplayMode.connectionAnim;
    _sequenceStep = 0;

    setState(() {
      _rpm = 0;
      _speed = 888; // Cluster self-check
      _gear = 8;
      _fuelBars = 6;
      _shiftLightOn = true;
      _btConnected = false;
      _ribbonText = 'TVS RACING      ';
    });

    _sequenceTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      _sequenceStep++;

      setState(() {
        if (_sequenceStep <= 5) {
          // Phase 1: Tachometer needle sweep to 12,000 RPM (Self test)
          _rpm = (_sequenceStep * 2400).clamp(0, 12000);
          _shiftLightOn = _rpm >= 10000;
        } else if (_sequenceStep == 6) {
          // Settle to idle
          _rpm = 1450;
          _speed = 0;
          _gear = 0; // Neutral
          _shiftLightOn = false;
          _ribbonText = '>>> MOTOLINK <<<';
        } else if (_sequenceStep == 8) {
          // Bluetooth Handshake established
          _btConnected = true;
          _signalBars = 5; // 5G 5 bars
          _ribbonText = 'LINK CONNECTED  ';
        } else if (_sequenceStep == 11) {
          // Greeting Frame
          _ribbonText = 'HELLO RIDER     ';
        } else if (_sequenceStep == 14) {
          // Ready to race
          _ribbonText = 'READY TO RACE   ';
        } else if (_sequenceStep == 18) {
          // Normal idle state
          _ribbonText = 'ODO: 3098 KM    ';
          timer.cancel();
        }
      });
    });
  }

  void _setNavigationMode() {
    _sequenceTimer?.cancel();
    _mode = LcdDisplayMode.navigationTbt;
    _tbtDistance = 180;
    _ribbonText = '<< 180m LEFT    ';

    _sequenceTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted || _mode != LcdDisplayMode.navigationTbt) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_tbtDistance > 20) {
          _tbtDistance -= 20;
          _ribbonText = '<< ${_tbtDistance}m LEFT    ';
        } else {
          _ribbonText = 'ROUNDABOUT 2ND  ';
        }
      });
    });
  }

  void _setMusicMode() {
    _sequenceTimer?.cancel();
    _mode = LcdDisplayMode.musicTrack;
    const track = 'BLINDING LIGHTS - THE WEEKND';
    const padded = 'SONG: $track    SONG: ';
    int offset = 0;

    _sequenceTimer = Timer.periodic(const Duration(milliseconds: 320), (timer) {
      if (!mounted || _mode != LcdDisplayMode.musicTrack) {
        timer.cancel();
        return;
      }
      setState(() {
        offset = (offset + 1) % (track.length + 4);
        final start = offset % track.length;
        _ribbonText = padded.substring(start, math.min(start + 16, padded.length)).padRight(16, ' ');
      });
    });
  }

  void _setRaceMode() {
    _sequenceTimer?.cancel();
    _mode = LcdDisplayMode.raceTelemetry;
    setState(() {
      _rpm = 8200;
      _speed = 78;
      _gear = 4;
      _ribbonText = 'LEAN: 36R • 0.8G';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: const Color(0xFF10141B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5A93C).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.9),
            blurRadius: 30,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFFE5A93C).withOpacity(0.18),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: TVS APACHE RTR 200 4V • DIGITAL CLUSTER SIMULATOR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TVS RACING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'RTR 200 4V LCD CLUSTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // THE PHYSICAL SPEEDOMETER BEZEL & WHITE-BACKLIT LCD DISPLAY
          _buildHardwareSpeedometerCluster(),

          const SizedBox(height: 16),

          // Cluster Interactive Mode Selectors
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModeChip(
                'IGNITION & CONNECT',
                Icons.power_settings_new,
                _mode == LcdDisplayMode.connectionAnim,
                _startIgnitionAndConnectionSequence,
              ),
              _buildModeChip(
                'TURN-BY-TURN TBT',
                Icons.turn_left,
                _mode == LcdDisplayMode.navigationTbt,
                _setNavigationMode,
              ),
              _buildModeChip(
                'MUSIC MARQUEE',
                Icons.music_note,
                _mode == LcdDisplayMode.musicTrack,
                _setMusicMode,
              ),
              _buildModeChip(
                'LEAN TELEMETRY',
                Icons.speed,
                _mode == LcdDisplayMode.raceTelemetry,
                _setRaceMode,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Explanatory Subtitle
          Text(
            'Simulating TVS SmartXonnect White-Backlit Segmented LCD & 14-Segment Bottom Ribbon over BLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF1B222C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5A93C) : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.white70),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Authentic TVS Apache RTR 200 4V White-Backlit LCD Cluster Frame
  Widget _buildHardwareSpeedometerCluster() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF06090D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C323D), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Authentic white-backlit dark LCD screen texture
          color: const Color(0xFF0A0F16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        ),
        child: Column(
          children: [
            // 1. Top Bezel: Shift Light + Tell-Tale Icons (Turn, ABS, Side Stand, High Beam)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildIconTellTale(Icons.arrow_back, false, Colors.green),
                    const SizedBox(width: 6),
                    _buildIconTellTale(Icons.lightbulb_outline, false, Colors.blue),
                    const SizedBox(width: 6),
                    _buildTextTellTale('ABS', true, Colors.amber),
                  ],
                ),
                // Red RPM Shift Light
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _shiftLightOn ? Colors.redAccent : const Color(0xFF3B1010),
                    boxShadow: _shiftLightOn
                        ? [const BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: 2)]
                        : null,
                  ),
                ),
                Row(
                  children: [
                    _buildTextTellTale('SIDE STAND', false, Colors.amber),
                    const SizedBox(width: 6),
                    _buildIconTellTale(Icons.arrow_forward, false, Colors.green),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 2. Tachometer Horizontal Segmented Bar (0 to 12,000 RPM)
            _buildTachometerBar(_rpm),

            const SizedBox(height: 10),

            // 3. Middle Main Section: Speedometer Big Digits + Gear + Mode + Bluetooth 5G
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gear Indicator & Ride Mode (Sport / Urban / Rain)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'GEAR',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _gear == 0 ? 'N' : '$_gear',
                            style: TextStyle(
                              color: _gear == 0 ? const Color(0xFF00E676) : Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5A93C).withOpacity(0.6)),
                      ),
                      child: const Text(
                        'SPORT',
                        style: TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                // Giant 7-Segment Speedometer Digits
                Column(
                  children: [
                    Text(
                      _speed.toString().padLeft(1, '0'),
                      style: const TextStyle(
                        color: Color(0xFFF3F4F6),
                        fontSize: 64,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: -2,
                        shadows: [
                          Shadow(color: Color(0xFF9CA3AF), blurRadius: 4),
                        ],
                      ),
                    ),
                    const Text(
                      'km/h',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                // Bluetooth Icon + 5G Signal Bars + Fuel Gauge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Bluetooth Status & Signal
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: 15,
                          color: _btConnected ? const Color(0xFF00E5FF) : Colors.white24,
                        ),
                        const SizedBox(width: 2),
                        // 5G Signal Bars
                        Row(
                          children: List.generate(5, (i) {
                            return Container(
                              margin: const EdgeInsets.only(left: 1.5),
                              width: 2.5,
                              height: 4.0 + (i * 2.2),
                              color: (_btConnected && i < _signalBars)
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white24,
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _btConnected ? '5G' : '--',
                      style: TextStyle(
                        color: _btConnected ? const Color(0xFF00E5FF) : Colors.white24,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Fuel Gauge Bar
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station, size: 12, color: Colors.white60),
                        const SizedBox(width: 3),
                        Row(
                          children: List.generate(6, (i) {
                            return Container(
                              margin: const EdgeInsets.only(left: 2),
                              width: 4,
                              height: 8,
                              color: i < _fuelBars ? Colors.white : Colors.white24,
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 4. THE 14-SEGMENT ALPHANUMERIC DOT-MATRIX LCD RIBBON (Where Animation Occurs)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF020406),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22D3EE).withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withOpacity(0.12),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dedicated Turn Arrow Indicator for TBT
                  if (_mode == LcdDisplayMode.navigationTbt) ...[
                    const Icon(Icons.turn_left, color: Color(0xFF22D3EE), size: 18),
                    const SizedBox(width: 8),
                  ],
                  // Alphanumeric 14-Segment Text with Monospace Dot-Matrix Appearance
                  Text(
                    _ribbonText,
                    style: const TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 2.2,
                      shadows: [
                        Shadow(color: Color(0xFF22D3EE), blurRadius: 10),
                      ],
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

  /// Top Tachometer segmented horizontal sweep bar (0 to 12)
  Widget _buildTachometerBar(int currentRpm) {
    const totalSegments = 24;
    final activeSegments = ((currentRpm / 12000) * totalSegments).round().clamp(0, totalSegments);

    return Column(
      children: [
        Row(
          children: List.generate(totalSegments, (i) {
            final isRedZone = i >= 18; // Above 9,000 RPM is redline
            final isLit = i < activeSegments;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 7,
                decoration: BoxDecoration(
                  color: isLit
                      ? (isRedZone ? Colors.redAccent : Colors.white)
                      : (isRedZone ? const Color(0xFF351212) : Colors.white12),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('2', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('4', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('6', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('8', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('10', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('12 x1000r/min', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildIconTellTale(IconData icon, bool active, Color activeColor) {
    return Icon(icon, size: 14, color: active ? activeColor : Colors.white24);
  }

  Widget _buildTextTellTale(String text, bool active, Color activeColor) {
    return Text(
      text,
      style: TextStyle(
        color: active ? activeColor : Colors.white24,
        fontSize: 8.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
