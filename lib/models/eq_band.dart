class EqBand {
  final int index;
  final int centerFreqHz;
  double levelDb;

  EqBand({
    required this.index,
    required this.centerFreqHz,
    required this.levelDb,
  });

  String get formattedFreq {
    if (centerFreqHz >= 1000) {
      final khz = centerFreqHz / 1000;
      return khz == khz.roundToDouble()
          ? '${khz.toInt()}kHz'
          : '${khz.toStringAsFixed(1)}kHz';
    }
    return '${centerFreqHz}Hz';
  }
}
