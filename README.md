# MotoLink 🏍️⚡

> **Next-Generation Open-Source Bluetooth Cockpit, Live Telemetry & Navigation Companion for Modern Connected Motorcycles**

MotoLink transforms your smartphone into a high-performance riding cockpit and companion for compatible motorcycle digital instrument clusters. Built with Flutter, it delivers ultra-low-latency BLE communication, live engine dynamics, turn-by-turn navigation mirroring, customizable handlebar switch gestures, and comprehensive ride logging — with **zero cloud dependencies** and **100% offline privacy**.

---

## ✨ Key Features

### 🎛️ 1. Real-Time Digital Cockpit HUD
- **Dynamic Gauges**: Live speedometer, linear sweep tachometer (RPM), digital gear indicator, and lean angle visualization.
- **Thermal & Electrical Health**: Real-time engine coolant/oil temperature monitoring and active 12V battery charging voltage tracking.
- **Fuel & Range Estimates**: Precision fuel percentage and dynamic Distance-to-Empty (DTE) calculations.
- **Tire Pressure Monitoring (TPMS)**: Dual-wheel real-time pressure (PSI) and temperature telemetry with low-pressure alert thresholds.

### 🧭 2. Turn-by-Turn GPS Navigation Assistant
- **Cluster Mirroring**: Translates live Google Maps / GPS turn maneuvers, distance countdowns, and upcoming road names directly to your motorcycle's instrument cluster display.
- **Adaptive Text Formatting**: Automatically segments and scrolls long road names onto 14-segment alphanumeric cluster ribbons without visual clipping.
- **Maneuver Pictograms**: Compact directional icons for turns, roundabouts, highway exits, and arrival waypoints.

### 🎮 3. Handlebar Switch & Gesture Remapping
- **Repurpose Hardware Buttons**: Map your motorcycle's handlebar buttons (such as the cluster control or info switch) to custom smartphone actions.
- **Multi-Gesture Engine**:
  - **Single Press**: Play / Pause audio playback or answer calls.
  - **Double Press**: Skip to next music track.
  - **Triple Press**: Previous track or toggle headlights indicator.
  - **Long Press**: Trigger Google Assistant / Voice Search or drop a GPS location bookmark.
- **Speed Dialing**: Rapidly trigger hands-free phone calls to emergency contacts without taking your hands off the grips.

### 📈 4. Ride Analytics & Blackbox Trip Logger
- **Session Telemetry**: Automatically records total route distance, duration, top speed, average speed, and acceleration times (0–60 km/h).
- **Vehicle Dynamics Tracking**: Logs peak lean angles (left/right) and maximum longitudinal/lateral G-forces.
- **Fuel Efficiency History**: Tracks instantaneous and cumulative economy (km/L) across daily commutes and long tours.
- **GPS Route Playback**: Visualizes past rides with interactive speed overlays and elevation profiles.

### ⚡ 5. Seamless Key-ON Auto-Connect
- **Ignition Watchdog**: Detects when the motorcycle key is turned on and instantly re-establishes encrypted communication in under 2 seconds.
- **Silent Background Operation**: Runs smoothly in the background while your phone remains safely tucked into your pocket or mounted on a handlebar holder.

### 🧪 6. Built-in Virtual Cluster Desk Simulator
- **Hardware-Free Testing**: Simulate live motorcycle telemetry right from your desk without needing to be physically near your bike.
- **Dynamic Telemetry Stream**: Generates sweeping RPM, gear shifts, accelerating speeds, and fluctuating lean angles with a single tap.

---

## 🛠️ System Architecture

```
┌────────────────────────────────────────────────────────┐
│                      MotoLink App                      │
├─────────────┬─────────────┬─────────────┬──────────────┤
│ Live Garage │ Digital HUD │ Navigation  │ Trip Tracker │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬───────┘
       │             │             │             │
┌──────┴─────────────┴─────────────┴─────────────┴───────┐
│              BleConnectionManager Service              │
│  - Android GATT Cache Flush   - MTU 512 Negotiation    │
│  - Multi-tier Fallbacks       - Ignition Auto-Watchdog │
└──────────────────────────┬─────────────────────────────┘
                           │ BLE 4.2 / 5.0 (SMP Encrypted)
┌──────────────────────────┴─────────────────────────────┐
│       Compatible Motorcycle Instrument Cluster         │
│  - Telemetry Stream (Notify)  - Navigation/Cmd (Write) │
└────────────────────────────────────────────────────────┘
```

### Protocol Resilience
- **GATT Cache Recovery**: Automatic Android GATT cache invalidation prevents stale Bluetooth handles and reconnection failures.
- **ATT MTU Negotiation**: Automatically requests `512` byte MTU buffers to prevent L2CAP packet truncation during rapid telemetry streaming.
- **Multi-Tier Characteristic Resolution**:
  1. *Tier 1*: Strict 16-bit / 128-bit UUID matching.
  2. *Tier 2*: Dynamic property inspection (`notify`/`indicate` for inbound telemetry, `write`/`writeWithoutResponse` for outbound navigation).
  3. *Tier 3*: Cross-vendor custom service adaptation.
- **Obfuscation & Checksum**: Symmetric stream cipher decryption and frame checksum verification ensures zero corrupted data enters the telemetry pipeline.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.4.3`
- **Dart SDK**: `>= 3.4.3 < 4.0.0`
- **Android**: Android 8.0 (API Level 26) or newer with Bluetooth Low Energy (BLE) support.

### Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/shanbiju/motolink.git
   cd motolink
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Static Analysis & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch on Device**:
   ```bash
   flutter run --release
   ```

5. **Build Standalone Release APK**:
   ```bash
   flutter build apk --release
   ```
   The compiled APK will be output to:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 📱 How to Connect

1. **First-Time Pairing**:
   - Turn on your smartphone's **Bluetooth** and **Location Services**.
   - Turn your motorcycle's ignition key to **ON** (cluster screen awake).
   - In MotoLink, navigate to the **Pairing** tab and tap **SCAN**.
   - Select your digital cluster from the list and tap **CONNECT**.
   - If prompted by your cluster screen, enter the dynamic 6-digit confirmation PIN.
2. **Everyday Riding**:
   - Keep **"Always Connect on Bike Start"** enabled.
   - Simply start your motorcycle and ride — MotoLink will link in the background automatically.

---

## 🔒 Privacy & Permissions

- **Bluetooth**: Required to communicate with the digital instrument cluster.
- **Location (GPS)**: Required by Android for BLE beacon scanning and to compute ride speeds, distances, and navigation.
- **Local Storage**: All trip records, stats, and configurations are stored purely locally on your device via encrypted SharedPreferences.
- **Zero Tracking**: MotoLink does not contain third-party ad SDKs or analytics trackers.

---

## ⚖️ Legal Disclaimer

MotoLink is an independent, open-source community software project designed for educational and enthusiast purposes. 

- This software is **not** endorsed by, sponsored by, directly affiliated with, or associated with any vehicle manufacturer or brand.
- All product names, logos, trademarks, and registered trademarks mentioned or referenced are properties of their respective owners.
- The use of these descriptions is strictly for hardware identification, interoperability, and compatibility explanation under fair use guidelines.
- Always observe safe riding practices and local traffic regulations. Never operate smartphone touch controls while the vehicle is in motion.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
