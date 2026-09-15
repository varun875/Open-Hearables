# Open Hearables 🎧

An ultra-lightweight, zero-tracking, open-source companion app for boAt and JieLi/Bluetrum Bluetooth earbuds (including Airdopes 311 Plus).

Built as an open-source alternative to proprietary 140MB+ bloatware, **Open Hearables** provides system-level audio DSP equalization, instant Bluetooth battery monitoring, and direct hardware low-latency control with zero logins and zero network requests.

---

## ⚡ Key Features

* **Universal 10-Band Equalizer (DSP):** Attaches directly to Android's native `AudioEffect` / `Equalizer` pipeline on Session 0. Works on **every single earbud** (including boAt models that are artificially whitelist-locked).
* **Beast Mode / Low-Latency Hardware Toggle:** Clean-room implementation of the **JieLi RCSP protocol** (`0xFE`, `0xDC`, `0xBA` frames) to toggle hardware low-latency mode without vendor bloatware.
* **Instant Battery Readout:** Reads vendor BLE advertisement beacons (JieLi `0x05D6`, Bluetrum `0x0642`) for per-bud and case levels, with the Bluetooth SIG GATT Battery Service (`0x180F` / `0x2A19`) as fallback.
* **100% Offline & Private:** Zero analytics, zero advertising SDKs, zero cloud logins.
* **Microscopic Footprint:** < 5 MB clean release APK vs 144 MB commercial app.

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────┐
│               Flutter UI (Material 3)                  │
│   • Battery Meters (L/R/Case) • Beast Mode Switch      │
│   • 10-Band Parametric EQ     • Sound Presets          │
└───────────────────────────┬────────────────────────────┘
                            │ MethodChannel
┌───────────────────────────▼────────────────────────────┐
│              Native Android Kotlin Plugins             │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ SystemEqualizerPlugin │   │   JieliRcspPlugin    │  │
│  │ (Session 0 AudioEffect│   │ (Hardware Low-Latency│  │
│  │  & BassBoost DSP)     │   │  Packet Generator)   │  │
│  └───────────────────────┘   └──────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.40+)
* Android SDK (API 26+)

### Platform Support

| Platform | Status |
| --- | --- |
| Android | ✅ Fully supported |
| iOS / macOS / Linux / Windows / Web | ⚠️ Not implemented — the native plugins are Android-only |

The non-Android platform folders are Flutter scaffolding only. On those
platforms the app renders but reports "Open Hearables currently supports
Android only"; Bluetooth, the system equalizer and Beast Mode are all inactive.

### Run on Connected Device
```bash
flutter run
```

The app requests Bluetooth permissions on first launch. On Android 11 and below
it also needs location permission, because BLE scanning is gated behind it;
Android 12+ uses `neverForLocation` and asks only for nearby-devices access.

### Build Production APK
```bash
flutter build apk --release
```

Release builds read their signing config from `android/key.properties`, which is
gitignored. Copy `android/key.properties.example`, generate a keystore and fill
in your credentials. Without that file the build still succeeds but is signed
with the debug key, and cannot be uploaded to Google Play.

### Development

```bash
flutter analyze                    # static analysis
flutter test                       # Dart unit + widget tests
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin unit tests (RCSP frames)
```

CI runs all three on every push and pull request.

---

## ⚖️ License
MIT License - Clean-room open-source implementation. See [LICENSE](LICENSE).
