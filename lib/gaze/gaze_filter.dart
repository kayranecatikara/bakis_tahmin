import 'dart:math' as math;

/// 1-Euro Filter implementasyonu
/// Referans: https://cristal.univ-lille.fr/~casiez/1euro/
class OneEuroFilter {
  /// Örnekleme frekansı (Hz)
  double frequency;

  /// Minimum kesim frekansı (Hz)
  double minCutoff;

  /// Türev kesim frekansı (Hz)
  double dCutoff;

  /// Hız katsayısı
  double beta;

  // İç durumlar
  double? _x;
  double? _dx;
  double? _lastTime;

  OneEuroFilter({
    required this.frequency,
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
  });

  /// Filtreyi sıfırla
  void reset() {
    _x = null;
    _dx = null;
    _lastTime = null;
  }

  /// Değeri filtrele
  double filter(double value, double timestamp) {
    if (_lastTime != null) {
      frequency = 1.0 / (timestamp - _lastTime!);
    }
    _lastTime = timestamp;

    // İlk değer
    if (_x == null) {
      _x = value;
      _dx = 0.0;
      return value;
    }

    // Türevi hesapla
    final double dx = (value - _x!) * frequency;

    // Türevi filtrele
    _dx = _lowPassFilter(_dx!, dx, _alpha(dCutoff));

    // Kesim frekansını hesapla
    final double cutoff = minCutoff + beta * _dx!.abs();

    // Değeri filtrele
    _x = _lowPassFilter(_x!, value, _alpha(cutoff));

    return _x!;
  }

  /// Low-pass filter
  double _lowPassFilter(double previous, double current, double alpha) {
    return alpha * current + (1.0 - alpha) * previous;
  }

  /// Alpha değerini hesapla
  double _alpha(double cutoff) {
    final double te = 1.0 / frequency;
    final double tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / te);
  }
}

/// 2D nokta için 1-Euro Filter
class OneEuroFilter2D {
  late OneEuroFilter _filterX;
  late OneEuroFilter _filterY;

  OneEuroFilter2D({
    required double frequency,
    required double minCutoff,
    required double beta,
    double dCutoff = 1.0,
  }) {
    _filterX = OneEuroFilter(
      frequency: frequency,
      minCutoff: minCutoff,
      beta: beta,
      dCutoff: dCutoff,
    );
    _filterY = OneEuroFilter(
      frequency: frequency,
      minCutoff: minCutoff,
      beta: beta,
      dCutoff: dCutoff,
    );
  }

  /// Parametreleri güncelle
  void updateParameters({double? minCutoff, double? beta}) {
    if (minCutoff != null) {
      _filterX.minCutoff = minCutoff;
      _filterY.minCutoff = minCutoff;
    }
    if (beta != null) {
      _filterX.beta = beta;
      _filterY.beta = beta;
    }
  }

  /// 2D noktayı filtrele
  (double x, double y) filter(double x, double y, double timestamp) {
    final filteredX = _filterX.filter(x, timestamp);
    final filteredY = _filterY.filter(y, timestamp);
    return (filteredX, filteredY);
  }

  /// Filtreleri sıfırla
  void reset() {
    _filterX.reset();
    _filterY.reset();
  }
}
