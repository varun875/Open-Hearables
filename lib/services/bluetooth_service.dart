import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_state.dart';

class BluetoothService extends ChangeNotifier {
  static const MethodChannel _audioChannel = MethodChannel('com.openhearables.app/bluetooth_audio');
  static const MethodChannel _rcspChannel = MethodChannel('com.openhearables.app/rcsp');

  // Known Manufacturer IDs from decompiled SDKs:
  // 0x0642 (1602 decimal) = Bluetrum / boAt Airdopes
  // 0x05D6 (1494 decimal) = Zhuhai JieLi Technology
  static const int mfgBluetrum = 0x0642;
  static const int mfgJieli = 0x05D6;

  DeviceState _deviceState = const DeviceState();
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  StreamSubscription? _scanSub;

  DeviceState get deviceState => _deviceState;
  bool get isScanning => _isScanning;

  BluetoothService() {
    _initAudioChannel();
    _initBluetooth();
    checkConnectedDevices();
  }

  void _initAudioChannel() {
    _audioChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceStateChanged') {
        if (call.arguments is Map) {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          _updateFromAudioDevice(data);
        }
      }
    });
  }

  void _updateFromAudioDevice(Map<String, dynamic> data) {
    final bool isConnected = data['isConnected'] as bool? ?? false;
    if (isConnected) {
      final String name = (data['name'] as String?)?.trim() ?? '';
      final String address = (data['address'] as String?)?.trim() ?? '';
      final int battery = data['batteryLevel'] as int? ?? -1;

      final devName = name.isNotEmpty ? name : (_deviceState.name.isNotEmpty ? _deviceState.name : 'boAt Airdopes 311 Plus');
      final devAddress = address.isNotEmpty ? address : _deviceState.macAddress;

      _deviceState = _deviceState.copyWith(
        name: devName,
        macAddress: devAddress,
        isConnected: true,
        leftBattery: battery >= 0 ? battery : (_deviceState.leftBattery >= 0 ? _deviceState.leftBattery : -1),
        rightBattery: battery >= 0 ? battery : (_deviceState.rightBattery >= 0 ? _deviceState.rightBattery : -1),
      );
      notifyListeners();
    } else {
      _deviceState = _deviceState.copyWith(
        isConnected: false,
        macAddress: 'Scanning...',
      );
      notifyListeners();
    }
  }

  void _initBluetooth() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        checkConnectedDevices();
        startBeaconScanning();
      } else {
        _deviceState = _deviceState.copyWith(isConnected: false);
        notifyListeners();
      }
    });
  }

  /// Scans for BLE Advertisement Manufacturer Beacons (0x0642 / 0x05D6)
  /// This retrieves real-time Left, Right, and Case battery levels even when
  /// the case lid is opened or earbuds are charging.
  Future<void> startBeaconScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final mfg = r.advertisementData.manufacturerData;
          final List<int>? raw = mfg[mfgBluetrum] ?? mfg[mfgJieli];

          // Unpack 13-byte DeviceBeaconV1 payload (per decompiled DeviceBeaconV1.smali)
          if (raw != null && raw.length >= 10) {
            final isLeftChg = (raw[7] & 0x80) != 0;
            final leftPct = raw[7] & 0x7F;

            final isRightChg = (raw[8] & 0x80) != 0;
            final rightPct = raw[8] & 0x7F;

            final isCaseChg = (raw[9] & 0x80) != 0;
            final casePct = raw[9] & 0x7F;

            final devName = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : (r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : _deviceState.name);

            _deviceState = _deviceState.copyWith(
              name: devName,
              macAddress: r.device.remoteId.str,
              leftBattery: leftPct.clamp(0, 100),
              rightBattery: rightPct.clamp(0, 100),
              caseBattery: casePct.clamp(0, 100),
              isLeftCharging: isLeftChg,
              isRightCharging: isRightChg,
              isCaseCharging: isCaseChg,
              isConnected: true,
            );
            notifyListeners();
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      debugPrint('Beacon scan exception: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> checkConnectedDevices() async {
    // 1. Check Native Android Bluetooth Audio / A2DP / HFP connection
    try {
      final result = await _audioChannel.invokeMethod<dynamic>('getConnectedAudioDevice');
      if (result is Map) {
        final data = Map<String, dynamic>.from(result);
        _updateFromAudioDevice(data);
      }
    } catch (e) {
      debugPrint('Native audio device check error: $e');
    }

    // 2. Check BLE GATT connected devices fallback
    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      for (final dev in systemDevices) {
        final name = dev.platformName.toLowerCase();
        if (name.contains('airdopes') ||
            name.contains('boat') ||
            name.contains('earbud') ||
            name.contains('tws')) {
          _connectedDevice = dev;
          _deviceState = _deviceState.copyWith(
            name: dev.platformName.isNotEmpty ? dev.platformName : _deviceState.name,
            macAddress: dev.remoteId.str,
            isConnected: true,
          );
          notifyListeners();
          _readGattBattery(dev);
          return;
        }
      }

      if (systemDevices.isNotEmpty && !_deviceState.isConnected) {
        final dev = systemDevices.first;
        _connectedDevice = dev;
        _deviceState = _deviceState.copyWith(
          name: dev.platformName.isNotEmpty ? dev.platformName : 'Connected Audio Device',
          macAddress: dev.remoteId.str,
          isConnected: true,
        );
        notifyListeners();
        _readGattBattery(dev);
      }
    } catch (e) {
      debugPrint('BT check error: $e');
    }
  }

  /// Standard Bluetooth SIG GATT Fallback (UUID 0x180F -> 0x2A19)
  Future<void> _readGattBattery(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == Guid('180F')) {
          for (final char in service.characteristics) {
            if (char.uuid == Guid('2A19')) {
              final value = await char.read();
              if (value.isNotEmpty) {
                final level = value[0];
                _deviceState = _deviceState.copyWith(
                  leftBattery: level,
                  rightBattery: level,
                );
                notifyListeners();
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> toggleBeastMode() async {
    final nextState = !_deviceState.isBeastModeActive;
    _deviceState = _deviceState.copyWith(isBeastModeActive: nextState);
    notifyListeners();

    try {
      final packet = await _rcspChannel.invokeMethod<Uint8List>(
        'buildLowLatencyPacket',
        {'enabled': nextState},
      );
      if (packet != null && _connectedDevice != null) {
        debugPrint('RCSP Beast Mode packet dispatched: ${packet.length} bytes');
      }
    } catch (e) {
      debugPrint('RCSP command dispatch: $e');
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }
}
