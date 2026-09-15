import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/beacon_battery.dart';
import '../models/device_state.dart';

class BluetoothService extends ChangeNotifier with WidgetsBindingObserver {
  static const MethodChannel _audioChannel =
      MethodChannel('com.openhearables.app/bluetooth_audio');
  static const MethodChannel _rcspChannel =
      MethodChannel('com.openhearables.app/rcsp');

  static const String _beastModePrefKey = 'is_beast_mode';
  static const String _disconnectedAddress = 'Scanning...';

  /// Minimum Android API level where `neverForLocation` removes the location
  /// requirement from BLE scanning.
  static const int _apiNeverForLocation = 31;

  /// Name fragments used to pick a likely TWS/audio device out of the bonded
  /// list. Deliberately broad — vendor branding varies wildly across the
  /// JieLi/Bluetrum OEM ecosystem.
  static const List<String> _twsNameHints = [
    'airdopes',
    'boat',
    'earbud',
    'tws',
    'buds',
    'airpods',
    'neckband',
    'jbl',
    'noise',
    'boult',
    'mivi',
    'oneplus',
    'realme',
    'redmi',
    'oppo',
    'jieli',
    'bluetrum',
  ];

  static final Guid _batteryLevelUuid = Guid('2A19');

  DeviceState _deviceState = const DeviceState();
  BluetoothDevice? _connectedDevice;
  String? _errorMessage;

  bool _isScanning = false;
  bool _startScanInFlight = false;
  bool _isCheckingDevices = false;
  bool _permissionsBlocked = false;
  bool _disposed = false;
  int? _cachedApiLevel;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<bool>? _isScanningSub;

  DeviceState get deviceState => _deviceState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;

  /// True when a permission was permanently denied, meaning only the system
  /// settings screen can unblock it.
  bool get permissionsBlocked => _permissionsBlocked;

  /// The native plugins backing this service are Android-only, so every
  /// Bluetooth path is disabled elsewhere.
  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  BluetoothService();

  /// Begins observing the adapter, the native audio channel and preferences.
  ///
  /// Kept out of the constructor so the service can be constructed without
  /// touching platform channels (tests).
  void init() {
    WidgetsBinding.instance.addObserver(this);
    _initAudioChannel();
    _initBluetooth();
    _loadPreferences();
    checkConnectedDevices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // The Quick Settings tile writes `is_beast_mode` from outside this process,
    // so re-read it (and the real connection state) whenever we come forward.
    _loadPreferences();
    checkConnectedDevices();
  }

  void _initAudioChannel() {
    _audioChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceStateChanged' && call.arguments is Map) {
        _updateFromAudioDevice(
          Map<String, dynamic>.from(call.arguments as Map),
        );
      }
    });
  }

  void _updateFromAudioDevice(Map<String, dynamic> data) {
    final isConnected = data['isConnected'] as bool? ?? false;
    if (!isConnected) {
      _deviceState = _deviceState.copyWith(
        isConnected: false,
        macAddress: _disconnectedAddress,
      );
      _notify();
      return;
    }

    final name = (data['name'] as String?)?.trim() ?? '';
    final address = (data['address'] as String?)?.trim() ?? '';
    final battery = data['batteryLevel'] as int? ?? -1;

    _deviceState = _deviceState.copyWith(
      name: name.isNotEmpty ? name : _deviceState.name,
      macAddress: address.isNotEmpty ? address : _deviceState.macAddress,
      isConnected: true,
      leftBattery: battery >= 0 ? battery : _deviceState.leftBattery,
      rightBattery: battery >= 0 ? battery : _deviceState.rightBattery,
    );
    _clearError();
    _notify();
  }

  void _initBluetooth() {
    if (!isSupported) {
      _setError('Open Hearables currently supports Android only.');
      return;
    }

    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (_disposed) return;

      if (state == BluetoothAdapterState.on) {
        _clearErrorWithoutNotify();
        checkConnectedDevices();
        startBeaconScanning();
      } else {
        _deviceState = _deviceState.copyWith(
          isConnected: false,
          macAddress: _disconnectedAddress,
        );
        _setError(
          state == BluetoothAdapterState.unauthorized
              ? 'Bluetooth permission denied. Enable it in system settings.'
              : 'Bluetooth is turned off.',
        );
      }
    });

    // The scan timeout is owned by the platform stream rather than the
    // startScan() future, which resolves as soon as scanning begins.
    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (_disposed || _isScanning == scanning) return;
      _isScanning = scanning;
      _notify();
    });
  }

  /// Re-checks the connection and kicks off a fresh beacon scan.
  Future<void> refresh() async {
    await checkConnectedDevices();
    await startBeaconScanning();
  }

  /// Requests whatever Bluetooth permissions the running Android version needs.
  Future<bool> ensurePermissions() async {
    if (!isSupported) return false;

    final apiLevel = await _androidApiLevel();
    final required = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Below API 31 BLE scanning is still gated behind location access;
      // `neverForLocation` only takes effect from API 31 onwards.
      if (apiLevel < _apiNeverForLocation) Permission.locationWhenInUse,
    ];

    final statuses = await required.request();
    final missing = required
        .where((permission) => !(statuses[permission]?.isGranted ?? false))
        .toList();
    if (missing.isEmpty) {
      _permissionsBlocked = false;
      _clearError();
      return true;
    }

    _permissionsBlocked =
        missing.any((permission) => statuses[permission]?.isPermanentlyDenied ?? false);
    _setError(
      _permissionsBlocked
          ? 'Bluetooth permissions are blocked. Grant them from system settings.'
          : 'Bluetooth permissions are required to find your earbuds.',
    );
    return false;
  }

  Future<void> openSystemSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Unable to open app settings: $e');
    }
  }

  Future<void> startBeaconScanning() async {
    if (!isSupported || _isScanning || _startScanInFlight) return;
    if (!await ensurePermissions()) return;

    _startScanInFlight = true;
    try {
      _scanSub ??= FlutterBluePlus.scanResults.listen(
        _onScanResults,
        onError: (Object e) => debugPrint('Beacon scan stream error: $e'),
      );
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _setError('Could not start Bluetooth scan: $e');
    } finally {
      _startScanInFlight = false;
    }
  }

  void _onScanResults(List<ScanResult> results) {
    if (_disposed) return;

    for (final result in results) {
      final battery = BeaconParser.parse(
        result.advertisementData.manufacturerData,
      );
      if (battery == null) continue;
      _applyBeacon(result, battery);
      return;
    }
  }

  /// Publishes battery readings from an advertisement.
  ///
  /// Advertisements keep arriving while the buds sit in a closed case, so this
  /// deliberately does *not* mark the device connected — that stays driven by
  /// the real A2DP/HFP/GATT link.
  void _applyBeacon(ScanResult result, BeaconBattery battery) {
    final advertiserName = result.advertisementData.advName;
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : (advertiserName.isNotEmpty ? advertiserName : _deviceState.name);

    _deviceState = _deviceState.copyWith(
      name: name,
      macAddress: result.device.remoteId.str,
      leftBattery: battery.leftPercent,
      rightBattery: battery.rightPercent,
      caseBattery: battery.hasCase ? battery.casePercent : _deviceState.caseBattery,
      isLeftCharging: battery.isLeftCharging,
      isRightCharging: battery.isRightCharging,
      isCaseCharging: battery.isCaseCharging,
    );
    _clearErrorWithoutNotify();
    _notify();
  }

  Future<void> checkConnectedDevices() async {
    if (!isSupported || _isCheckingDevices) return;
    _isCheckingDevices = true;

    try {
      await _checkNativeAudioDevice();
      await _checkSystemDevices();
    } finally {
      _isCheckingDevices = false;
    }
  }

  Future<void> _checkNativeAudioDevice() async {
    try {
      final result = await _audioChannel.invokeMethod<dynamic>(
        'getConnectedAudioDevice',
      );
      if (result is Map) {
        _updateFromAudioDevice(Map<String, dynamic>.from(result));
      }
    } catch (e) {
      debugPrint('Native audio device check failed: $e');
    }
  }

  Future<void> _checkSystemDevices() async {
    try {
      final systemDevices = await FlutterBluePlus.systemDevices(const []);
      if (systemDevices.isEmpty) return;

      final preferred = systemDevices.firstWhere(
        (device) => _looksLikeTws(device.platformName),
        orElse: () => systemDevices.first,
      );

      _connectedDevice = preferred;
      _deviceState = _deviceState.copyWith(
        name: preferred.platformName.isNotEmpty
            ? preferred.platformName
            : _deviceState.name,
        macAddress: preferred.remoteId.str,
        isConnected: true,
      );
      _notify();

      await _readGattBattery(preferred);
    } catch (e) {
      debugPrint('System device check failed: $e');
    }
  }

  bool _looksLikeTws(String name) {
    final lowered = name.toLowerCase();
    return _twsNameHints.any(lowered.contains);
  }

  /// Standard Bluetooth SIG Battery Service fallback.
  ///
  /// The characteristic is looked up across every advertised service rather
  /// than only `0x180F`, because a lot of TWS firmware hangs `0x2A19` off a
  /// vendor service.
  Future<void> _readGattBattery(BluetoothDevice device) async {
    // Beacon data is per-bud; don't downgrade it to a single combined reading.
    if (_deviceState.leftBattery >= 0 && _deviceState.rightBattery >= 0) return;
    if (!device.isConnected) return;

    try {
      final services = await device.discoverServices();
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid != _batteryLevelUuid) continue;
          if (!characteristic.properties.read) continue;

          final value = await characteristic.read();
          if (value.isEmpty) continue;

          final level = value[0];
          if (level < 0 || level > 100) continue;

          _deviceState = _deviceState.copyWith(
            leftBattery: level,
            rightBattery: level,
          );
          _notify();
          return;
        }
      }
    } catch (e) {
      debugPrint('GATT battery read failed: $e');
    }
  }

  Future<void> toggleBeastMode() async {
    if (!_deviceState.isConnected) {
      _setError('Connect your earbuds before toggling Beast Mode.');
      return;
    }

    final nextState = !_deviceState.isBeastModeActive;
    _deviceState = _deviceState.copyWith(isBeastModeActive: nextState);
    _notify();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_beastModePrefKey, nextState);
    } catch (e) {
      debugPrint('Beast Mode preference write failed: $e');
    }

    try {
      final packet = await _rcspChannel.invokeMethod<Uint8List>(
        'buildLowLatencyPacket',
        {'enabled': nextState},
      );
      if (packet == null || packet.isEmpty) {
        _setError('Could not build the Beast Mode command.');
        return;
      }

      final dispatched = await _audioChannel.invokeMethod<bool>(
        'sendRcspPacket',
        {'packet': packet},
      );
      if (dispatched != true) {
        _setError('Your earbuds did not acknowledge the Beast Mode command.');
      } else {
        _clearError();
      }
    } catch (e) {
      _setError('Beast Mode command failed: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // External writers (the QS tile) bypass the in-memory cache.
      await prefs.reload();

      final savedBeast = prefs.getBool(_beastModePrefKey) ?? false;
      if (savedBeast == _deviceState.isBeastModeActive) return;

      _deviceState = _deviceState.copyWith(isBeastModeActive: savedBeast);
      _notify();
    } catch (e) {
      debugPrint('Beast Mode preference read failed: $e');
    }
  }

  Future<int> _androidApiLevel() async {
    if (_cachedApiLevel != null) return _cachedApiLevel!;

    try {
      final info = await _audioChannel.invokeMethod<Map>('getPlatformInfo');
      _cachedApiLevel = info?['apiLevel'] as int?;
    } catch (_) {
      // Native channel unavailable; assume a version that needs no location.
    }
    return _cachedApiLevel ??= _apiNeverForLocation;
  }

  /// `notifyListeners()` throws once the notifier is disposed, and several
  /// async paths can outlive it.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _setError(String message) {
    if (_disposed) return;
    _errorMessage = message;
    _notify();
  }

  void _clearError() {
    if (_disposed || _errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  void _clearErrorWithoutNotify() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _isScanningSub?.cancel();
    _audioChannel.setMethodCallHandler(null);
    super.dispose();
  }
}
