import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/protocol/packet_builder.dart';
import '../../core/theme/app_colors.dart';
import '../media/cluster_media_service.dart';
import 'google_maps_service.dart';
import 'navigation_models.dart';

class NavigationDispatchView extends ConsumerStatefulWidget {
  const NavigationDispatchView({super.key});

  @override
  ConsumerState<NavigationDispatchView> createState() => _NavigationDispatchViewState();
}

class _NavigationDispatchViewState extends ConsumerState<NavigationDispatchView> {
  // Google Maps Destination controls
  final TextEditingController _destinationController =
      TextEditingController(text: 'Koramangala Bangalore');
  bool _motorcycleMode = true;

  // Turn-by-turn bridge controls
  final TextEditingController _instructionInputController =
      TextEditingController(text: 'In 350 m, turn right onto MG ROAD');
  final TextEditingController _streetController =
      TextEditingController(text: 'MG ROAD');
  ManeuverType _selectedManeuver = ManeuverType.turnRight;
  int _distanceMeters = 350;
  bool _autoDispatch = true;

  Uint8List? _lastGeneratedPacket;
  String _dispatchStatus = 'Ready to dispatch';
  bool _isManualTuningExpanded = false;

  @override
  void initState() {
    super.initState();
    _parseCurrentInstruction(autoSend: false);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _instructionInputController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  /// Parses raw Google Maps text instruction and updates maneuver, distance & street
  void _parseCurrentInstruction({bool autoSend = false}) {
    final raw = _instructionInputController.text.trim();
    if (raw.isEmpty) return;

    final parsed = GoogleMapsNavigationService.instance.parseGoogleMapsInstruction(raw);
    setState(() {
      _selectedManeuver = parsed.maneuver;
      _distanceMeters = parsed.distanceMeters;
      _streetController.text = parsed.streetName;
    });

    _updatePacketPreview();

    if (autoSend && _autoDispatch) {
      _dispatchPacket();
    }
  }

  void _updatePacketPreview() {
    final adapter = ref.read(bleManagerProvider).adapter;
    final instruction = NavigationInstruction(
      maneuver: _selectedManeuver,
      distanceMeters: _distanceMeters,
      streetName: _streetController.text,
    );
    setState(() {
      _lastGeneratedPacket = adapter.buildNavigationPacket(instruction);
    });
  }

  Future<void> _dispatchPacket() async {
    final bleManager = ref.read(bleManagerProvider);
    final instruction = NavigationInstruction(
      maneuver: _selectedManeuver,
      distanceMeters: _distanceMeters,
      streetName: _streetController.text,
    );

    final success = await bleManager.dispatchNavigation(instruction);
    if (success) {
      ClusterMediaService.instance.notifyNavigationDispatched();
    }
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _dispatchStatus = success
          ? 'Packet dispatched successfully at $timeStr'
          : 'Dispatch failed (Bluetooth disconnected or cluster characteristic unavailable)';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.warning_amber_rounded,
                color: success ? AppColors.background : AppColors.textLight,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _dispatchStatus,
                  style: TextStyle(
                    color: success ? AppColors.background : AppColors.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: success ? AppColors.accent : Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchGoogleMaps() async {
    final dest = _destinationController.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a destination first'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    final launched = await GoogleMapsNavigationService.instance.launchGoogleMapsNavigation(
      destination: dest,
      motorcycleMode: _motorcycleMode,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps navigation intent'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = ref.watch(bleManagerProvider);
    final adapter = bleManager.adapter;
    final sanitizedPreview = TvsPacketBuilder.sanitizeForLcd(
      _streetController.text,
      maxLength: adapter.maxStreetLength,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 10,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 26,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'MOTOLINK NAV',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  color: AppColors.textLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Google Maps Navigation Launcher Card
            _buildGoogleMapsLauncherCard(),
            const SizedBox(height: 16),

            // 2. LCD Hardware Cluster Preview (Fixed overflow)
            _buildLcdClusterPreview(sanitizedPreview, adapter.maxStreetLength),
            const SizedBox(height: 16),

            // 3. Live Turn-by-Turn Instruction Bridge Card (Fixed overflow)
            _buildInstructionBridgeCard(adapter),
            const SizedBox(height: 16),

            // 4. Packet Inspector Card
            _buildPacketInspector(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMapsLauncherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.06),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOOGLE MAPS 2-WHEELER MODE',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Turn-by-turn routing to motorcycle cluster',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Two wheeler toggle badge
              InkWell(
                onTap: () {
                  setState(() => _motorcycleMode = !_motorcycleMode);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _motorcycleMode
                        ? AppColors.accent.withOpacity(0.18)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _motorcycleMode ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _motorcycleMode ? Icons.two_wheeler : Icons.directions_car,
                        color: _motorcycleMode ? AppColors.accent : AppColors.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _motorcycleMode ? '2W Active' : 'Car Mode',
                        style: TextStyle(
                          color: _motorcycleMode ? AppColors.accent : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Destination Input Field
          TextField(
            controller: _destinationController,
            style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              prefixIcon: const Icon(Icons.search, color: AppColors.accent),
              suffixIcon: _destinationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        setState(() => _destinationController.clear());
                      },
                    )
                  : null,
              labelText: 'Destination / Address / Landmark',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Destination Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickDestChip('Work', Icons.work_outline),
                const SizedBox(width: 8),
                _buildQuickDestChip('Home', Icons.home_outlined),
                const SizedBox(width: 8),
                _buildQuickDestChip('Fuel Station', Icons.local_gas_station_outlined),
                const SizedBox(width: 8),
                _buildQuickDestChip('Hospital', Icons.local_hospital_outlined),
                const SizedBox(width: 8),
                _buildQuickDestChip('TVS Service', Icons.build_circle_outlined),
                const SizedBox(width: 8),
                _buildQuickDestChip('Airport', Icons.flight_takeoff_outlined),
                const SizedBox(width: 8),
                _buildQuickDestChip('ATM', Icons.local_atm_outlined),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Launch Google Maps Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _launchGoogleMaps,
              icon: const Icon(Icons.assistant_navigation, color: AppColors.background),
              label: const Text(
                'LAUNCH GOOGLE MAPS (2-WHEELER MODE)',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDestChip(String name, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, color: AppColors.accent, size: 16),
      label: Text(
        name,
        style: const TextStyle(color: AppColors.textLight, fontSize: 12),
      ),
      backgroundColor: AppColors.surfaceLight,
      side: const BorderSide(color: AppColors.border),
      onPressed: () {
        setState(() => _destinationController.text = name);
      },
    );
  }

  Widget _buildLcdClusterPreview(String text, int maxLen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Expanded to completely avoid the 23-pixel right overflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.monitor, color: AppColors.accent, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'APACHE RTR 200 LCD CLUSTER PREVIEW',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GLYPH [ ${_selectedManeuver.glyphLetter} ]',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 14-seg Icon box
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: AppColors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  _selectedManeuver.glyphLetter,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Alphanumeric 14-seg Ribbon
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_distanceMeters M',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionBridgeCard(dynamic adapter) {
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
          // Row with Expanded to completely avoid the 9.2-pixel right overflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'LIVE NAVIGATION BRIDGE',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Auto-Dispatch',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: _autoDispatch,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      setState(() => _autoDispatch = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Live Text Instruction Input
          TextField(
            controller: _instructionInputController,
            style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              prefixIcon: const Icon(Icons.directions, color: AppColors.accent),
              suffixIcon: IconButton(
                icon: const Icon(Icons.sync, color: AppColors.accent),
                tooltip: 'Parse & Send Instruction',
                onPressed: () => _parseCurrentInstruction(autoSend: true),
              ),
              labelText: 'Google Maps Turn Instruction',
              hintText: 'e.g. In 450 m, turn right onto Hosur Road',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              hintStyle: const TextStyle(color: Colors.white24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            onChanged: (_) => _parseCurrentInstruction(autoSend: _autoDispatch),
          ),
          const SizedBox(height: 12),

          // Quick Turn Presets
          const Text(
            'QUICK INSTRUCTION PRESETS',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildInstructionPresetChip('Turn right in 350m on MG Road'),
                const SizedBox(width: 8),
                _buildInstructionPresetChip('In 150m, sharp left onto Ring Road'),
                const SizedBox(width: 8),
                _buildInstructionPresetChip('At roundabout take 2nd exit'),
                const SizedBox(width: 8),
                _buildInstructionPresetChip('U-turn in 500m on NH 44'),
                const SizedBox(width: 8),
                _buildInstructionPresetChip('Destination reached'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dispatch Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _dispatchPacket,
              icon: const Icon(Icons.send_rounded, color: AppColors.background),
              label: const Text(
                'DISPATCH TO INSTRUMENT CLUSTER',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Expandable Fine Tuning
          InkWell(
            onTap: () {
              setState(() => _isManualTuningExpanded = !_isManualTuningExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _isManualTuningExpanded ? Icons.expand_less : Icons.tune,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isManualTuningExpanded ? 'Hide Manual Fine-Tuning' : 'Manual Fine-Tuning Controls',
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          if (_isManualTuningExpanded) ...[
            const Divider(color: AppColors.border, height: 20),

            // Maneuver Dropdown
            DropdownButtonFormField<ManeuverType>(
              value: _selectedManeuver,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                labelText: 'Turn Maneuver',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: ManeuverType.values.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.glyphLetter,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(m.label, style: const TextStyle(color: AppColors.textLight)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedManeuver = val);
                  _updatePacketPreview();
                  if (_autoDispatch) _dispatchPacket();
                }
              },
            ),
            const SizedBox(height: 16),

            // Distance Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distance to Turn',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                Text(
                  '$_distanceMeters meters',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _distanceMeters.toDouble(),
              min: 10,
              max: 2000,
              divisions: 199,
              activeColor: AppColors.accent,
              inactiveColor: AppColors.border,
              onChanged: (val) {
                setState(() => _distanceMeters = val.round());
                _updatePacketPreview();
              },
              onChangeEnd: (val) {
                if (_autoDispatch) _dispatchPacket();
              },
            ),
            const SizedBox(height: 12),

            // Street Name Input
            TextField(
              controller: _streetController,
              maxLength: adapter.maxStreetLength,
              style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                labelText: 'Street Name (Max ${adapter.maxStreetLength} Chars for LCD)',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                counterStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              onChanged: (_) {
                _updatePacketPreview();
                if (_autoDispatch) _dispatchPacket();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionPresetChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(color: AppColors.textLight, fontSize: 11),
      ),
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      onPressed: () {
        _instructionInputController.text = text;
        _parseCurrentInstruction(autoSend: true);
      },
    );
  }

  Widget _buildPacketInspector() {
    final hexString = _lastGeneratedPacket != null
        ? _lastGeneratedPacket!
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ')
        : 'None';

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
              Icon(Icons.terminal, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RAW SMARTXONNECT BLE PACKET INSPECTOR',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              hexString,
              style: const TextStyle(
                color: AppColors.accent,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dispatchStatus,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
