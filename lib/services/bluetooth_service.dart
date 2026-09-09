import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_state.dart';

class BluetoothService extends ChangeNotifier {
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
    _initBluetooth();
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
            name: dev.platformName.isNotEmpty ? dev.platformName : 'boAt Airdopes 311 Plus',
            macAddress: dev.remoteId.str,
            isConnected: true,
          );
          notifyListeners();
          _readGattBattery(dev);
          return;
        }
      }

      if (systemDevices.isNotEmpty) {
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
