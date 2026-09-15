/// Battery levels decoded from a manufacturer-specific BLE advertisement beacon.
class BeaconBattery {
  final int leftPercent;
  final int rightPercent;
  final int casePercent;
  final bool isLeftCharging;
  final bool isRightCharging;
  final bool isCaseCharging;

  const BeaconBattery({
    required this.leftPercent,
    required this.rightPercent,
    this.casePercent = -1,
    this.isLeftCharging = false,
    this.isRightCharging = false,
    this.isCaseCharging = false,
  });

  bool get hasCase => casePercent >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeaconBattery &&
          other.leftPercent == leftPercent &&
          other.rightPercent == rightPercent &&
          other.casePercent == casePercent &&
          other.isLeftCharging == isLeftCharging &&
          other.isRightCharging == isRightCharging &&
          other.isCaseCharging == isCaseCharging;

  @override
  int get hashCode => Object.hash(
        leftPercent,
        rightPercent,
        casePercent,
        isLeftCharging,
        isRightCharging,
        isCaseCharging,
      );

  @override
  String toString() =>
      'BeaconBattery(left: $leftPercent, right: $rightPercent, case: $casePercent)';
}

/// Decodes battery levels out of TWS advertisement manufacturer data.
///
/// Two vendor layouts are recognised, taken from the decompiled vendor SDKs:
///
/// * JieLi (`0x05D6`) — `NotifyAdvInfoParam`: left/right/case at bytes 14/15/16,
///   where bit `0x80` of each byte is the charging flag and the low 7 bits are
///   the percentage.
/// * Bluetrum (`0x0642`) — `DeviceBeaconV1`: the same three values live at bytes
///   7/8/9.
abstract final class BeaconParser {
  static const int manufacturerBluetrum = 0x0642;
  static const int manufacturerJieli = 0x05D6;

  static const int _chargingMask = 0x80;
  static const int _levelMask = 0x7F;

  static const int _jieliMinLength = 17;
  static const int _bluetrumMinLength = 10;

  /// Parses [manufacturerData] (manufacturer id -> raw payload) into battery
  /// levels, preferring the JieLi layout when both are present.
  ///
  /// Returns `null` when no recognised beacon carries usable data, so callers
  /// can fall back instead of publishing bogus values.
  static BeaconBattery? parse(Map<int, List<int>> manufacturerData) {
    final jieli = manufacturerData[manufacturerJieli];
    if (jieli != null && jieli.length >= _jieliMinLength) {
      return _decode(jieli, 14);
    }

    final bluetrum = manufacturerData[manufacturerBluetrum];
    if (bluetrum != null && bluetrum.length >= _bluetrumMinLength) {
      return _decode(bluetrum, 7);
    }

    return null;
  }

  static BeaconBattery _decode(List<int> raw, int offset) {
    final left = _level(raw[offset]);
    final right = _level(raw[offset + 1]);
    final caseLevel = _level(raw[offset + 2]);

    return BeaconBattery(
      leftPercent: left,
      rightPercent: right,
      casePercent: caseLevel,
      isLeftCharging: _isCharging(raw[offset]),
      isRightCharging: _isCharging(raw[offset + 1]),
      isCaseCharging: _isCharging(raw[offset + 2]),
    );
  }

  static int _level(int byte) => (byte & _levelMask).clamp(0, 100);

  static bool _isCharging(int byte) => (byte & _chargingMask) != 0;
}
