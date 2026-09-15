import 'package:flutter_test/flutter_test.dart';

import 'package:open_hearables/models/beacon_battery.dart';

void main() {
  group('BeaconParser', () {
    test('decodes the JieLi battery triple', () {
      final raw = List<int>.filled(17, 0);
      raw[14] = 88;
      raw[15] = 0x80 | 55; // right earbud charging
      raw[16] = 100;

      final battery = BeaconParser.parse({BeaconParser.manufacturerJieli: raw})!;

      expect(battery.leftPercent, 88);
      expect(battery.rightPercent, 55);
      expect(battery.casePercent, 100);
      expect(battery.isLeftCharging, isFalse);
      expect(battery.isRightCharging, isTrue);
      expect(battery.isCaseCharging, isFalse);
    });

    test('decodes the Bluetrum battery triple at its own offsets', () {
      final raw = List<int>.filled(10, 0);
      raw[7] = 0x80 | 42; // left earbud charging
      raw[8] = 17;
      raw[9] = 0x80 | 90; // case charging

      final battery =
          BeaconParser.parse({BeaconParser.manufacturerBluetrum: raw})!;

      expect(battery.leftPercent, 42);
      expect(battery.rightPercent, 17);
      expect(battery.casePercent, 90);
      expect(battery.isLeftCharging, isTrue);
      expect(battery.isRightCharging, isFalse);
      expect(battery.isCaseCharging, isTrue);
    });

    test('prefers the JieLi layout when both are advertised', () {
      final jieli = List<int>.filled(17, 0)..[14] = 10;
      final bluetrum = List<int>.filled(10, 0)..[7] = 20;

      final battery = BeaconParser.parse({
        BeaconParser.manufacturerJieli: jieli,
        BeaconParser.manufacturerBluetrum: bluetrum,
      })!;

      expect(battery.leftPercent, 10);
    });

    test('returns null for unknown manufacturers', () {
      expect(
        BeaconParser.parse({0x1234: List<int>.filled(20, 0x7F)}),
        isNull,
      );
    });

    test('returns null when the payload cannot hold the triple', () {
      expect(
        BeaconParser.parse({
          BeaconParser.manufacturerJieli: List<int>.filled(16, 0),
        }),
        isNull,
      );
      expect(
        BeaconParser.parse({
          BeaconParser.manufacturerBluetrum: List<int>.filled(9, 0),
        }),
        isNull,
      );
    });

    test('clamps implausible levels to 100', () {
      // 0x7F masks to 127 before clamping.
      final raw = List<int>.filled(17, 0x7F);

      final battery = BeaconParser.parse({BeaconParser.manufacturerJieli: raw})!;

      expect(battery.leftPercent, 100);
      expect(battery.rightPercent, 100);
      expect(battery.casePercent, 100);
    });

    test('charging bit does not leak into the reported level', () {
      final raw = List<int>.filled(17, 0);
      raw[14] = 0x80 | 63;
      raw[15] = 63;
      raw[16] = 63;

      final battery = BeaconParser.parse({BeaconParser.manufacturerJieli: raw})!;

      expect(battery.leftPercent, 63);
      expect(battery.isLeftCharging, isTrue);
    });
  });
}
