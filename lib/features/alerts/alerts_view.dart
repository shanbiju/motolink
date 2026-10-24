import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_colors.dart';

class AlertsView extends ConsumerWidget {
  const AlertsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider);

    final alerts = <Map<String, dynamic>>[];

    if (telemetry.isSideStandDown) {
      alerts.add({
        'title': 'Side Stand Deployed',
        'desc': 'Engine interlock active. Retract side stand before riding.',
        'severity': 'critical',
        'icon': Icons.warning_rounded,
      });
    }

    if (telemetry.batteryVoltage < 12.0 && telemetry.batteryVoltage > 0) {
      alerts.add({
        'title': 'Low Battery Voltage',
        'desc': 'Battery is at ${telemetry.batteryVoltage.toStringAsFixed(1)}V (Weak). Charge or inspect alternator.',
        'severity': 'warning',
        'icon': Icons.battery_alert_rounded,
      });
    }

    if (telemetry.isAbsMilActive) {
      alerts.add({
        'title': 'ABS Malfunction Indicator (MIL)',
        'desc': 'ABS sensor warning detected. Ride with caution.',
        'severity': 'critical',
        'icon': Icons.car_crash_rounded,
      });
    }

    if (telemetry.frontTyrePsi != null && telemetry.frontTyrePsi! < 28.0) {
      alerts.add({
        'title': 'Low Front Tyre Pressure',
        'desc': 'Pressure is ${telemetry.frontTyrePsi!.toStringAsFixed(1)} PSI (Recommended: 32 PSI).',
        'severity': 'warning',
        'icon': Icons.tire_repair,
      });
    }

    // Default notifications if no critical alerts active
    if (alerts.isEmpty) {
      alerts.add({
        'title': 'All Motorcycle Systems Normal',
        'desc': 'Side stand retracted, battery healthy (12.3V+), ABS ready.',
        'severity': 'ok',
        'icon': Icons.check_circle_outline,
      });
      alerts.add({
        'title': 'Routine Maintenance',
        'desc': 'Next periodic service due at 10,000 km or in 45 days.',
        'severity': 'info',
        'icon': Icons.build_circle_outlined,
      });
      alerts.add({
        'title': 'Bluetooth Auto-Connect Watchdog',
        'desc': 'MotoLink is listening for Apache / SmartXonnect ignition broadcast.',
        'severity': 'info',
        'icon': Icons.bluetooth_connected,
      });
    }

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
                'MOTOLINK ALERTS',
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
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, index) {
          final item = alerts[index];
          final severity = item['severity'] as String;

          Color borderColor = AppColors.border;
          Color iconColor = AppColors.accent;
          if (severity == 'critical') {
            borderColor = Colors.redAccent;
            iconColor = Colors.redAccent;
          } else if (severity == 'warning') {
            borderColor = Colors.orangeAccent;
            iconColor = Colors.orangeAccent;
          } else if (severity == 'ok') {
            borderColor = const Color(0xFF4CAF50);
            iconColor = const Color(0xFF4CAF50);
          }

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['desc'] as String,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
