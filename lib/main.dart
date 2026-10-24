import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ble/ble_models.dart';
import 'core/ble/ble_providers.dart';
import 'core/theme/app_colors.dart';
import 'features/alerts/alerts_view.dart';
import 'features/garage/garage_home_view.dart';
import 'features/navigation/navigation_dispatch_view.dart';
import 'features/pairing/pairing_screen.dart';
import 'features/media/cluster_media_service.dart';
import 'features/media/notification_media_service.dart';
import 'features/rides/my_rides_view.dart';
import 'features/rides/ride_telemetry_view.dart';
import 'features/telemetry/live_cockpit_view.dart';
import 'features/telemetry/motolink_connected_overlay.dart';
import 'features/telemetry/trip_recorder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TripRecorderService.instance.init();
  await ClusterMediaService.instance.init();
  await NotificationMediaService.instance.init();
  runApp(const MotoLinkApp());
}

class MotoLinkApp extends StatelessWidget {
  const MotoLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'MOTOLINK',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system, // Uses System Theme Default
        theme: AppColors.lightTheme,  // Crisp pearl white & gold theme
        darkTheme: AppColors.darkTheme,
        home: const MainNavigationShell(),
      ),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final stage = ref.watch(connectionStageProvider);

    // Auto-switch to Cockpit and trigger cinematic "MOTOLINK LINK CONNECTED" animation
    ref.listen<ConnectionStage>(connectionStageProvider, (prev, next) {
      if ((next == ConnectionStage.authenticated ||
              next == ConnectionStage.streamingTelemetry) &&
          prev != next) {
        final bikeName = ref.read(bleManagerProvider).selectedBike?.name ??
            ref.read(bleManagerProvider).savedBikeName ??
            'TVS APACHE RTR 200 4V';
        MotoLinkConnectedOverlay.show(context, bikeName: bikeName);

        if (_currentIndex == 5) {
          setState(() => _currentIndex = 1);
        }
      }
    });

    final screens = [
      GarageHomeView(
        onOpenPairing: () => setState(() => _currentIndex = 5),
        onOpenCockpit: () => setState(() => _currentIndex = 1),
      ),
      LiveCockpitView(
        onOpenFindMyVehicle: () => setState(() => _currentIndex = 0),
      ),
      RideTelemetryView(
        onOpenFullTripLog: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyRidesView()),
          );
        },
      ),
      const NavigationDispatchView(),
      const AlertsView(),
      const PairingScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.borderOf(context), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.accentOf(context),
          unselectedItemColor: AppColors.textMutedOf(context),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          onTap: (idx) => setState(() => _currentIndex = idx),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.two_wheeler),
              label: 'Garage',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.speed),
              label: 'Cockpit',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Rides',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.navigation_outlined),
              label: 'Navigation',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                stage.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
              ),
              label: 'Pairing',
            ),
          ],
        ),
      ),
    );
  }
}
