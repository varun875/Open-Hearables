import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/eq_band.dart';

class EqualizerService extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.openhearables.app/equalizer');

  /// Sentinel preset representing a curve the user edited by hand.
  static const String customPresetName = 'Custom';

  /// Single key holding the whole persisted state as JSON.
  static const String _statePrefKey = 'eq_state';

  static const List<int> _defaultFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  /// Factory curves, authored against the 10-band reference layout. They are
  /// resampled onto the device's actual band count before being applied.
  static const Map<String, List<double>> presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [7.0, 6.0, 4.5, 2.0, 0, 0, 1.0, 2.0, 3.0, 3.5],
    'Vocal Clarity': [-2.0, -1.0, 0, 1.5, 3.5, 4.0, 3.0, 1.5, 0, -1.0],
    'Rock (V-Shape)': [6.0, 4.5, 2.0, -1.0, -2.0, -1.0, 2.0, 4.0, 5.5, 6.0],
    'Electronic': [8.0, 7.0, 5.0, 1.0, 0, 2.0, 3.5, 5.0, 6.5, 7.0],
    'Acoustic': [3.0, 2.0, 1.0, 2.0, 3.0, 3.0, 2.5, 3.0, 3.5, 4.0],
  };

  bool _isEnabled = true;
  double _bassBoost = 0.3; // 0.0 to 1.0
  String _currentPreset = 'Bass Boost';
  List<EqBand> _bands = [];
  Map<String, List<double>> _customPresets = {};
  List<double>? _customCurve;
  bool _bassBoostSupported = true;
  double _minLevelDb = -12.0;
  double _maxLevelDb = 12.0;

  bool get isEnabled => _isEnabled;
  double get bassBoost => _bassBoost;
  bool get bassBoostSupported => _bassBoostSupported;
  String get currentPreset => _currentPreset;
  List<EqBand> get bands => List.unmodifiable(_bands);
  Map<String, List<double>> get customPresets => Map.unmodifiable(_customPresets);
  double get minLevelDb => _minLevelDb;
  double get maxLevelDb => _maxLevelDb;

  EqualizerService() {
    // Defaults are installed synchronously so the first frame always has bands
    // to render, then refined once the native effect reports its real layout.
    _bands = List<EqBand>.generate(
      _defaultFrequencies.length,
      (i) => EqBand(
        index: i,
        centerFreqHz: _defaultFrequencies[i],
        levelDb: presets['Bass Boost']![i],
      ),
    );
  }

  /// Loads the native effect layout and any persisted state.
  ///
  /// Kept out of the constructor so the service can be constructed without
  /// touching platform channels (tests, and any context before the first frame).
  Future<void> init() async {
    // Ordering matters: both steps used to push their own state to the native
    // effect, so whichever finished last silently won. Initialise first, load
    // preferences second, then sync exactly once.
    await _initNative();
    await _loadPreferences();
    await _syncAllToNative();
  }

  Future<void> _initNative() async {
    try {
      final res = await _channel.invokeMethod<Map>('init');
      if (res == null || res['supported'] != true) return;

      final nativeBands = res['bands'] as List? ?? const [];
      if (nativeBands.isEmpty) return;

      _bands = nativeBands.map((b) {
        final band = b as Map;
        final idx = band['index'] as int;
        final freq = (band['centerFreq'] as int) ~/ 1000; // mHz to Hz
        final level = (band['level'] as int) / 100.0; // millibels to dB
        return EqBand(index: idx, centerFreqHz: freq, levelDb: level);
      }).toList();

      _readNativeRange(res);
      _bassBoostSupported = res['bassBoostSupported'] as bool? ?? true;
    } catch (e) {
      debugPrint('Native EQ init fallback: $e');
    }
  }

  void _readNativeRange(Map res) {
    final min = res['minLevel'];
    final max = res['maxLevel'];
    if (min is! int || max is! int || min >= max) return;
    _minLevelDb = min / 100.0;
    _maxLevelDb = max / 100.0;
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    notifyListeners();
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {}
    await _savePreferences();
  }

  Future<void> setBandLevel(int index, double levelDb) async {
    if (index < 0 || index >= _bands.length) return;

    _bands[index] = _bands[index].copyWith(levelDb: _clampLevel(levelDb));
    _currentPreset = customPresetName;
    _customCurve = _gains();
    notifyListeners();

    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': _bands[index].index,
        'level': _toMillibels(_bands[index].levelDb),
      });
    } catch (_) {}
    await _savePreferences();
  }

  Future<void> setBassBoost(double strength) async {
    _bassBoost = strength.clamp(0.0, 1.0);
    notifyListeners();

    try {
      await _channel.invokeMethod('setBassBoost', {
        'strength': (_bassBoost * 1000).toInt(),
      });
    } catch (_) {}
    await _savePreferences();
  }

  Future<void> saveCustomPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == customPresetName) return;

    _customPresets[trimmed] = _gains();
    _currentPreset = trimmed;
    notifyListeners();
    await _savePreferences();
  }

  Future<void> deleteCustomPreset(String name) async {
    if (!_customPresets.containsKey(name)) return;

    _customPresets.remove(name);
    if (_currentPreset == name) {
      _currentPreset = customPresetName;
      _customCurve = _gains();
    }
    notifyListeners();
    await _savePreferences();
  }

  Future<void> applyPreset(String presetName) async {
    if (presetName == customPresetName) {
      _applyCurve(_customCurve ?? _gains());
    } else {
      final curve = presets[presetName] ?? _customPresets[presetName];
      if (curve == null) return;
      _applyCurve(curve);
    }

    _currentPreset = presetName;
    notifyListeners();
    await _syncAllToNative();
    await _savePreferences();
  }

  void _applyCurve(List<double> curve) {
    final mapped = mapCurveToBands(curve, _bands.length);
    for (var i = 0; i < _bands.length; i++) {
      _bands[i] = _bands[i].copyWith(levelDb: _clampLevel(mapped[i]));
    }
  }

  /// Resamples a reference curve onto [count] bands, preserving both endpoints.
  /// Exposed for testing.
  @visibleForTesting
  static List<double> mapCurveToBands(List<double> curve, int count) {
    if (count <= 0 || curve.isEmpty) return const <double>[];
    if (curve.length == count) return List<double>.from(curve);
    if (count == 1) return <double>[curve.first];

    return List<double>.generate(count, (i) {
      final sourceIndex = (i * (curve.length - 1) / (count - 1)).round();
      return curve[sourceIndex];
    });
  }

  List<double> _gains() => _bands.map((b) => b.levelDb).toList();

  double _clampLevel(double levelDb) => levelDb.clamp(_minLevelDb, _maxLevelDb);

  int _toMillibels(double levelDb) => (levelDb * 100).round();

  Future<void> _syncAllToNative() async {
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': _isEnabled});
      await _channel.invokeMethod('setBassBoost', {
        'strength': (_bassBoost * 1000).toInt(),
      });

      for (final band in _bands) {
        await _channel.invokeMethod('setBandLevel', {
          'band': band.index,
          'level': _toMillibels(band.levelDb),
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _statePrefKey,
        jsonEncode({
          'enabled': _isEnabled,
          'bassBoost': _bassBoost,
          'preset': _currentPreset,
          'gains': _gains(),
          'customCurve': _customCurve,
          'customPresets': _customPresets,
        }),
      );
    } catch (e) {
      debugPrint('EQ preference save failed: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statePrefKey);
      if (raw == null) return;

      final state = jsonDecode(raw) as Map<String, dynamic>;
      _isEnabled = state['enabled'] as bool? ?? _isEnabled;
      _bassBoost = (state['bassBoost'] as num?)?.toDouble() ?? _bassBoost;
      _currentPreset = state['preset'] as String? ?? _currentPreset;
      _customCurve = _decodeCurve(state['customCurve']);
      _customPresets = _decodePresets(state['customPresets']);

      // Saved gains are indexed by band, so they are only reusable when the
      // device still exposes the same number of bands.
      final gains = _decodeCurve(state['gains']);
      if (gains != null && gains.length == _bands.length) {
        for (var i = 0; i < _bands.length; i++) {
          _bands[i] = _bands[i].copyWith(levelDb: _clampLevel(gains[i]));
        }
      } else if (_currentPreset != customPresetName) {
        final curve = presets[_currentPreset] ?? _customPresets[_currentPreset];
        if (curve != null) _applyCurve(curve);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('EQ preference load failed: $e');
    }
  }

  static List<double>? _decodeCurve(Object? value) {
    if (value is! List) return null;
    return value.map((e) => (e as num).toDouble()).toList();
  }

  static Map<String, List<double>> _decodePresets(Object? value) {
    if (value is! Map) return {};
    return value.map((key, val) => MapEntry(
          key as String,
          (val as List).map((e) => (e as num).toDouble()).toList(),
        ));
  }
}
