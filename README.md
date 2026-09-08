# Open Hearables 🎧

An ultra-lightweight, zero-tracking, open-source companion app for boAt and JieLi/Bluetrum Bluetooth earbuds (including Airdopes 311 Plus).

Built as an open-source alternative to proprietary 140MB+ bloatware, **Open Hearables** provides system-level audio DSP equalization, instant Bluetooth battery monitoring, and direct hardware low-latency control with zero logins and zero network requests.

---

## ⚡ Key Features

* **Universal 10-Band Equalizer (DSP):** Attaches directly to Android's native `AudioEffect` / `Equalizer` pipeline on Session 0. Works on **every single earbud** (including boAt models that are artificially whitelist-locked).
* **Beast Mode / Low-Latency Hardware Toggle:** Clean-room implementation of the **JieLi RCSP protocol** (`0xBA`, `0xDC` frames) to toggle hardware low-latency mode without vendor bloatware.
* **Instant Battery Readout:** Reads native Bluetooth SIG GATT Battery Service (`0x180F` / `0x2A19`) for dual earbuds and case.
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

### Run on Connected Device
```bash
flutter run
```

### Build Production APK
```bash
flutter build apk --release
```

---

## ⚖️ License
MIT License - Clean-room open-source implementation.
