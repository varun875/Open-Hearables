/// A single equalizer band. Immutable; mutate by creating a copy via [copyWith].
class EqBand {
  final int index;
  final int centerFreqHz;
  final double levelDb;

  const EqBand({
    required this.index,
    required this.centerFreqHz,
    required this.levelDb,
  });

  EqBand copyWith({
    int? index,
    int? centerFreqHz,
    double? levelDb,
  }) {
    return EqBand(
      index: index ?? this.index,
      centerFreqHz: centerFreqHz ?? this.centerFreqHz,
      levelDb: levelDb ?? this.levelDb,
    );
  }

  String get formattedFreq {
    if (centerFreqHz >= 1000) {
      final khz = centerFreqHz / 1000;
      return khz == khz.roundToDouble()
          ? '${khz.toInt()}kHz'
          : '${khz.toStringAsFixed(1)}kHz';
    }
    return '${centerFreqHz}Hz';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqBand &&
          other.index == index &&
          other.centerFreqHz == centerFreqHz &&
          other.levelDb == levelDb;

  @override
  int get hashCode => Object.hash(index, centerFreqHz, levelDb);

  @override
  String toString() =>
      'EqBand(index: $index, centerFreqHz: $centerFreqHz, levelDb: $levelDb)';
}
