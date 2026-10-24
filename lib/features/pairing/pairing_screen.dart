import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_connection_manager.dart';
import '../../core/ble/ble_models.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_colors.dart';
import '../ibutton/ibutton_service.dart';
import '../telemetry/motolink_connected_overlay.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showPinDialog(BuildContext context, WidgetRef ref) {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.dialpad, color: AppColors.accent),
            SizedBox(width: 10),
            Text(
              'Enter Cluster PIN',
              style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Read the 6-digit dynamic PIN generated on your Apache instrument cluster display:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.4), letterSpacing: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(bleManagerProvider).disconnect();
            },
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final pin = _pinController.text.trim();
              if (pin.length == 6) {
                Navigator.pop(dialogCtx);
                final success = await ref.read(bleManagerProvider).submitPin(pin);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN pairing failed. Please verify and retry.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('PAIR & CONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = ref.watch(bleManagerProvider);
    final bikes = bleManager.discoveredBikes;

    // Listen for awaitingPin state to show PIN dialog automatically
    ref.listen<ConnectionStage>(connectionStageProvider, (prev, next) {
      if (next == ConnectionStage.awaitingPin) {
        _showPinDialog(context, ref);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'MOTOLINK',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Connection Status Card
          _buildStatusBanner(context, bleManager),

          // Auto-Connect on Ignition & i-Button Remapper Card
          _buildSmartFeaturesCard(context, bleManager),

          // Scanning Controls & Filter Selector
          _buildScanControls(context, bleManager),

          // Discovered Devices Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DISCOVERED BLUETOOTH DEVICES',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${bikes.length} Found',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),

          // Discovered Devices List
          Expanded(
            child: bikes.isEmpty
                ? _buildEmptyState(bleManager)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bikes.length,
                    itemBuilder: (ctx, idx) => _buildBikeTile(context, ref, bikes[idx], bleManager),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, dynamic bleManager) {
    Color bannerColor;
    IconData bannerIcon;

    switch (bleManager.stage as ConnectionStage) {
      case ConnectionStage.disconnected:
        bannerColor = AppColors.textMuted;
        bannerIcon = Icons.bluetooth_disabled;
        break;
      case ConnectionStage.scanning:
        bannerColor = AppColors.info;
        bannerIcon = Icons.radar;
        break;
      case ConnectionStage.connecting:
        bannerColor = AppColors.accent;
        bannerIcon = Icons.sync;
        break;
      case ConnectionStage.awaitingPin:
        bannerColor = AppColors.accent;
        bannerIcon = Icons.dialpad;
        break;
      case ConnectionStage.authenticated:
      case ConnectionStage.streamingTelemetry:
        bannerColor = AppColors.accent;
        bannerIcon = Icons.bluetooth_connected;
        break;
      case ConnectionStage.reconnecting:
        bannerColor = AppColors.accent;
        bannerIcon = Icons.power_settings_new;
        break;
      case ConnectionStage.error:
        bannerColor = AppColors.error;
        bannerIcon = Icons.error_outline;
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(bannerIcon, color: bannerColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (bleManager.stage as ConnectionStage).displayName,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bleManager.errorMessage ??
                      (bleManager.selectedBike != null
                          ? 'Target: ${bleManager.selectedBike!.name}'
                          : 'Pair your TVS Apache SmartXonnect cluster'),
                  style: TextStyle(
                    color: bleManager.errorMessage != null ? AppColors.error : AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (bleManager.stage == ConnectionStage.connecting || bleManager.stage == ConnectionStage.reconnecting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
        ],
      ),
    );
  }

  Widget _buildScanControls(BuildContext context, dynamic bleManager) {
    final isScanning = bleManager.stage == ConnectionStage.scanning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isScanning ? AppColors.surfaceLight : AppColors.accent,
                foregroundColor: isScanning ? AppColors.textLight : AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (isScanning) {
                  bleManager.stopScan();
                } else {
                  bleManager.startScan();
                }
              },
              icon: Icon(
                isScanning ? Icons.stop : Icons.search,
                color: isScanning ? AppColors.textLight : AppColors.background,
              ),
              label: Text(
                isScanning ? 'STOP SCAN' : 'SCAN FOR APACHE',
                style: TextStyle(
                  color: isScanning ? AppColors.textLight : AppColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent, width: 1.4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              MotoLinkConnectedOverlay.show(
                context,
                bikeName: bleManager.selectedBike?.name ?? 'TVS APACHE RTR 200 4V',
              );
            },
            icon: const Icon(Icons.play_circle_fill, size: 18),
            label: const Text(
              'ANIMATION',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic bleManager) {
    final isScanning = bleManager.stage == ConnectionStage.scanning;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.asset(
                'assets/images/logo.png',
                height: 52,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isScanning
                  ? 'Searching for SmartXonnect BLE signals...'
                  : 'No TVS Motorcycles Found Yet',
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Turn on bike ignition to activate the Bluetooth cluster transmitter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBikeTile(
    BuildContext context,
    WidgetRef ref,
    DiscoveredBike bike,
    dynamic bleManager,
  ) {
    final isConnecting = bleManager.selectedBike?.id == bike.id &&
        bleManager.stage == ConnectionStage.connecting;

    final upper = bike.name.toUpperCase();
    final isTvs = upper.startsWith('RMB') ||
        upper.contains('TVS') ||
        upper.contains('RTR') ||
        upper.contains('APACHE') ||
        upper.contains('SMARTXONNECT');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnecting
              ? AppColors.accent
              : (isTvs ? AppColors.accent.withOpacity(0.5) : AppColors.border),
          width: isTvs ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isTvs ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isTvs ? Icons.two_wheeler : Icons.bluetooth,
              color: isTvs ? AppColors.accent : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bike.name,
                        style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (bike.isPaired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'PAIRED',
                          style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isTvs ? AppColors.accent.withOpacity(0.2) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isTvs
                              ? (bike.adapter.modelName.contains('310') ? 'TVS TFT' : 'TVS SmartXonnect')
                              : 'Bluetooth Device',
                          style: TextStyle(
                            color: isTvs ? AppColors.accent : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Text(
                      bike.isNearby ? '${bike.rssi} dBm' : 'Turn Ignition ON',
                      style: TextStyle(
                        color: bike.isNearby ? AppColors.textMuted : AppColors.accent,
                        fontSize: 11,
                        fontWeight: bike.isNearby ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isConnecting ? null : () => bleManager.connect(bike),
              child: isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                    )
                  : Text(
                      bike.isPaired ? 'CONNECT' : 'PAIR',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartFeaturesCard(BuildContext context, BleConnectionManager bleManager) {
    final ibutton = IButtonService.instance;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Auto-Connect on Ignition Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flash_on, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Always Connect on Bike Start',
                      style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      bleManager.savedBikeName != null
                          ? 'Paired: ${bleManager.savedBikeName} (Ignition Watchdog)'
                          : 'Auto-reconnects as soon as key is turned on',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: bleManager.autoConnectEnabled,
                activeColor: AppColors.accent,
                onChanged: (val) {
                  bleManager.setAutoConnectEnabled(val);
                },
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 16),

          // Handlebar i-Button Remapping Tile
          InkWell(
            onTap: () => _showIButtonPicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(ibutton.currentAction.icon, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Handlebar "i-Button" Action',
                              style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'REMAPPED',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          ibutton.currentAction.title,
                          style: const TextStyle(color: AppColors.accent, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIButtonPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final current = IButtonService.instance.currentAction;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          child: const Icon(Icons.touch_app, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Remap Handlebar "i-Button"',
                                style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Intercepts cluster Call Cancel / Info switch for custom actions',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: IButtonAction.values.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (ctx, idx) {
                          final action = IButtonAction.values[idx];
                          final isSelected = action == current;

                          return ListTile(
                            leading: Icon(
                              action.icon,
                              color: isSelected ? AppColors.accent : AppColors.textMuted,
                            ),
                            title: Text(
                              action.title,
                              style: TextStyle(
                                color: isSelected ? AppColors.accent : AppColors.textLight,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              action.description,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppColors.accent, size: 18)
                                : null,
                            onTap: () async {
                              await IButtonService.instance.setAction(action);
                              setModalState(() {});
                              setState(() {});
                              if (context.mounted) Navigator.pop(bCtx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
