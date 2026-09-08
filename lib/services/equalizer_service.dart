import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/eq_band.dart';

class EqualizerService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.openhearables.app/equalizer');

  bool _isEnabled = true;
  double _bassBoost = 0.3; // 0.0 to 1.0
  String _currentPreset = 'Bass Boost';
  List<EqBand> _bands = [];

  bool get isEnabled => _isEnabled;
  double get bassBoost => _bassBoost;
  String get currentPreset => _currentPreset;
  List<EqBand> get bands => _bands;

  static const Map<String, List<double>> presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [7.0, 6.0, 4.5, 2.0, 0, 0, 1.0, 2.0, 3.0, 3.5],
    'Vocal Clarity': [-2.0, -1.0, 0, 1.5, 3.5, 4.0, 3.0, 1.5, 0, -1.0],
    'Rock (V-Shape)': [6.0, 4.5, 2.0, -1.0, -2.0, -1.0, 2.0, 4.0, 5.5, 6.0],
    'Electronic': [8.0, 7.0, 5.0, 1.0, 0, 2.0, 3.5, 5.0, 6.5, 7.0],
    'Acoustic': [3.0, 2.0, 1.0, 2.0, 3.0, 3.0, 2.5, 3.0, 3.5, 4.0],
  };

  EqualizerService() {
    _initDefaultBands();
    _initNative();
    _loadPreferences();
  }

  void _initDefaultBands() {
    final defaultFrequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    final defaultGains = presets['Bass Boost']!;

    _bands = List.generate(
      defaultFrequencies.length,
      (i) => EqBand(
        index: i,
        centerFreqHz: defaultFrequencies[i],
        levelDb: defaultGains[i],
      ),
    );
  }

  Future<void> _initNative() async {
    try {
      final res = await _channel.invokeMethod<Map>('init');
      if (res != null && res['supported'] == true) {
        final List nativeBands = res['bands'] as List? ?? [];
        if (nativeBands.isNotEmpty) {
          _bands = nativeBands.map((b) {
            final idx = b['index'] as int;
            final freq = (b['centerFreq'] as int) ~/ 1000; // mHz to Hz
            final level = (b['level'] as int) / 100.0; // millibels to dB
            return EqBand(index: idx, centerFreqHz: freq, levelDb: level);
          }).toList();
        }
      }
      await _syncAllToNative();
    } catch (e) {
      debugPrint('Native EQ init fallback: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    notifyListeners();
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {}
    _savePreferences();
  }

  Future<void> setBandLevel(int index, double levelDb) async {
    if (index < 0 || index >= _bands.length) return;
    _bands[index].levelDb = levelDb.clamp(-12.0, 12.0);
    _currentPreset = 'Custom';
    notifyListeners();

    try {
      final millibels = (_bands[index].levelDb * 100).toInt();
      await _channel.invokeMethod('setBandLevel', {'band': index, 'level': millibels});
    } catch (_) {}
    _savePreferences();
  }

  Future<void> setBassBoost(double strength) async {
    _bassBoost = strength.clamp(0.0, 1.0);
    notifyListeners();

    try {
      final nativeStrength = (_bassBoost * 1000).toInt();
      await _channel.invokeMethod('setBassBoost', {'strength': nativeStrength});
    } catch (_) {}
    _savePreferences();
  }

  Future<void> applyPreset(String presetName) async {
    if (!presets.containsKey(presetName)) return;
    _currentPreset = presetName;
    final curve = presets[presetName]!;

    for (int i = 0; i < _bands.length && i < curve.length; i++) {
      _bands[i].levelDb = curve[i];
    }
    notifyListeners();
    await _syncAllToNative();
    _savePreferences();
  }

  Future<void> _syncAllToNative() async {
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': _isEnabled});
      final nativeStrength = (_bassBoost * 1000).toInt();
      await _channel.invokeMethod('setBassBoost', {'strength': nativeStrength});

      for (final band in _bands) {
        final millibels = (band.levelDb * 100).toInt();
        await _channel.invokeMethod('setBandLevel', {'band': band.index, 'level': millibels});
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _isEnabled);
    await prefs.setDouble('bass_boost', _bassBoost);
    await prefs.setString('eq_preset', _currentPreset);
    for (int i = 0; i < _bands.length; i++) {
      await prefs.setDouble('eq_band_$i', _bands[i].levelDb);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('eq_enabled') ?? true;
    _bassBoost = prefs.getDouble('bass_boost') ?? 0.3;
    _currentPreset = prefs.getString('eq_preset') ?? 'Bass Boost';

    for (int i = 0; i < _bands.length; i++) {
      final savedGain = prefs.getDouble('eq_band_$i');
      if (savedGain != null) {
        _bands[i].levelDb = savedGain;
      }
    }
    notifyListeners();
    await _syncAllToNative();
  }
}
