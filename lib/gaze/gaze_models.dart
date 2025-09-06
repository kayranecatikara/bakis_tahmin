/// Gaze frame veri modeli
class GazeFrame {
  /// Normalize edilmiş X koordinatı [0..1]
  final double x;

  /// Normalize edilmiş Y koordinatı [0..1]
  final double y;

  /// Tahmin güveni [0..1]
  final double confidence;

  /// Frame zaman damgası (milliseconds)
  final int timestamp;

  /// Frame geçerliliği (yüz/göz takibi başarılı mı?)
  final bool valid;

  const GazeFrame({
    required this.x,
    required this.y,
    required this.confidence,
    required this.timestamp,
    required this.valid,
  });

  /// JSON'dan GazeFrame oluştur
  factory GazeFrame.fromJson(Map<String, dynamic> json) {
    return GazeFrame(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      valid: json['valid'] as bool,
    );
  }

  /// GazeFrame'i JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'confidence': confidence,
      'timestamp': timestamp,
      'valid': valid,
    };
  }

  /// Kopyala ve değiştir
  GazeFrame copyWith({
    double? x,
    double? y,
    double? confidence,
    int? timestamp,
    bool? valid,
  }) {
    return GazeFrame(
      x: x ?? this.x,
      y: y ?? this.y,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      valid: valid ?? this.valid,
    );
  }

  @override
  String toString() {
    return 'GazeFrame(x: $x, y: $y, confidence: $confidence, timestamp: $timestamp, valid: $valid)';
  }
}
