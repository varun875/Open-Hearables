import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_hearables/services/equalizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('mapCurveToBands', () {
    test('returns the curve unchanged when the band counts match', () {
      const curve = [1.0, 2.0, 3.0];

      expect(EqualizerService.mapCurveToBands(curve, 3), curve);
    });

    test('preserves both endpoints when resampling onto fewer bands', () {
      final result = EqualizerService.mapCurveToBands(
        EqualizerService.presets['Bass Boost']!,
        5,
      );

      expect(result, hasLength(5));
      expect(result.first, 7.0);
      expect(result.last, 3.5);
    });

    test('collapses to a single band when only one is available', () {
      expect(EqualizerService.mapCurveToBands(const [1.0, 2.0, 3.0], 1), [1.0]);
    });

    test('returns an empty curve for degenerate input', () {
      expect(EqualizerService.mapCurveToBands(const [], 5), isEmpty);
      expect(EqualizerService.mapCurveToBands(const [1.0], 0), isEmpty);
    });
  });

  group('EqualizerService', () {
    test('starts on the Bass Boost curve with ten bands', () {
      final service = EqualizerService();

      expect(service.bands, hasLength(10));
      expect(service.currentPreset, 'Bass Boost');
      expect(service.bands.first.levelDb, 7.0);
    });

    test('moving a slider switches to the Custom preset', () async {
      final service = EqualizerService();

      await service.setBandLevel(0, 5.0);

      expect(service.currentPreset, EqualizerService.customPresetName);
      expect(service.bands.first.levelDb, 5.0);
    });

    test('clamps band levels to the supported range', () async {
      final service = EqualizerService();

      await service.setBandLevel(0, 999);
      expect(service.bands.first.levelDb, service.maxLevelDb);

      await service.setBandLevel(0, -999);
      expect(service.bands.first.levelDb, service.minLevelDb);
    });

    test('ignores out-of-range band indices', () async {
      final service = EqualizerService();

      await service.setBandLevel(99, 5.0);

      expect(service.currentPreset, 'Bass Boost');
    });

    test('restores the manual curve after visiting a factory preset', () async {
      final service = EqualizerService();

      await service.setBandLevel(0, 5.0);
      await service.applyPreset('Flat');
      expect(service.bands.first.levelDb, 0.0);

      await service.applyPreset(EqualizerService.customPresetName);
      expect(service.bands.first.levelDb, 5.0);
    });

    test('reserves the Custom name when saving a preset', () async {
      final service = EqualizerService();

      await service.saveCustomPreset(EqualizerService.customPresetName);

      expect(service.customPresets, isEmpty);
    });

    test('saves and deletes a named preset', () async {
      final service = EqualizerService();

      await service.saveCustomPreset('My Curve');
      expect(service.customPresets.keys, contains('My Curve'));
      expect(service.currentPreset, 'My Curve');

      await service.deleteCustomPreset('My Curve');
      expect(service.customPresets, isEmpty);
      expect(service.currentPreset, EqualizerService.customPresetName);
    });

    test('persists state across instances', () async {
      final first = EqualizerService();
      await first.setBandLevel(3, -4.5);
      await first.setBassBoost(0.75);

      final second = EqualizerService();
      await second.init();

      expect(second.bands[3].levelDb, -4.5);
      expect(second.bassBoost, 0.75);
      expect(second.currentPreset, EqualizerService.customPresetName);
    });

    test('tracks enable/disable state', () async {
      final service = EqualizerService();

      await service.setEnabled(false);

      expect(service.isEnabled, isFalse);
    });
  });
}
