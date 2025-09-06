import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import '../gaze/gaze_models.dart';

/// Kalibrasyon noktası
class CalibrationPoint {
  final double measuredX;
  final double measuredY;
  final double targetX;
  final double targetY;

  const CalibrationPoint({
    required this.measuredX,
    required this.measuredY,
    required this.targetX,
    required this.targetY,
  });

  Map<String, dynamic> toJson() => {
    'measuredX': measuredX,
    'measuredY': measuredY,
    'targetX': targetX,
    'targetY': targetY,
  };

  factory CalibrationPoint.fromJson(Map<String, dynamic> json) {
    return CalibrationPoint(
      measuredX: json['measuredX'],
      measuredY: json['measuredY'],
      targetX: json['targetX'],
      targetY: json['targetY'],
    );
  }
}

/// 2D Afine dönüşüm matrisi
class AffineTransform {
  // [a b tx]
  // [c d ty]
  // [0 0 1 ]
  final double a, b, c, d, tx, ty;

  const AffineTransform({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

  /// Noktayı dönüştür
  (double x, double y) transform(double x, double y) {
    final newX = a * x + b * y + tx;
    final newY = c * x + d * y + ty;
    return (newX, newY);
  }

  Map<String, dynamic> toJson() => {
    'a': a,
    'b': b,
    'c': c,
    'd': d,
    'tx': tx,
    'ty': ty,
  };

  factory AffineTransform.fromJson(Map<String, dynamic> json) {
    return AffineTransform(
      a: json['a'],
      b: json['b'],
      c: json['c'],
      d: json['d'],
      tx: json['tx'],
      ty: json['ty'],
    );
  }

  /// Birim dönüşüm (identity)
  factory AffineTransform.identity() {
    return const AffineTransform(
      a: 1.0,
      b: 0.0,
      tx: 0.0,
      c: 0.0,
      d: 1.0,
      ty: 0.0,
    );
  }
}

/// Kalibrasyon servisi
class CalibrationService {
  List<CalibrationPoint> _calibrationPoints = [];
  AffineTransform? _transform;
  bool _isCalibrated = false;

  bool get isCalibrated => _isCalibrated;
  List<CalibrationPoint> get calibrationPoints =>
      List.unmodifiable(_calibrationPoints);

  /// Kalibrasyon noktası ekle
  void addCalibrationPoint(CalibrationPoint point) {
    _calibrationPoints.add(point);
  }

  /// Kalibrasyon noktalarını temizle
  void clearCalibrationPoints() {
    _calibrationPoints.clear();
    _transform = null;
    _isCalibrated = false;
  }

  /// Afine dönüşüm hesapla (en küçük kareler yöntemi)
  /// En az 3 nokta gerekli
  bool calculateTransform() {
    if (_calibrationPoints.length < 3) {
      print('Kalibrasyon için en az 3 nokta gerekli');
      return false;
    }

    // Least squares ile afine dönüşüm hesaplama
    // X' = aX + bY + tx
    // Y' = cX + dY + ty

    final n = _calibrationPoints.length;

    // Matrisleri oluştur
    double sumX = 0, sumY = 0, sumXX = 0, sumYY = 0, sumXY = 0;
    double sumXp = 0, sumYp = 0, sumXXp = 0, sumYYp = 0, sumXYp = 0;

    for (final point in _calibrationPoints) {
      sumX += point.measuredX;
      sumY += point.measuredY;
      sumXX += point.measuredX * point.measuredX;
      sumYY += point.measuredY * point.measuredY;
      sumXY += point.measuredX * point.measuredY;

      sumXp += point.targetX;
      sumYp += point.targetY;
      sumXXp += point.measuredX * point.targetX;
      sumYYp += point.measuredY * point.targetY;
      sumXYp += point.measuredX * point.targetY;
    }

    // Normal denklemler çöz
    final det =
        n * (sumXX * sumYY - sumXY * sumXY) -
        sumX * (sumX * sumYY - sumY * sumXY) +
        sumY * (sumX * sumXY - sumY * sumXX);

    if (det.abs() < 1e-10) {
      print('Kalibrasyon noktaları doğrusal bağımlı!');
      return false;
    }

    // Basitleştirilmiş çözüm (tam least squares yerine)
    // Bu ilk versiyon için yeterli
    final avgX = sumX / n;
    final avgY = sumY / n;
    final avgXp = sumXp / n;
    final avgYp = sumYp / n;

    // Basit ölçekleme ve öteleme
    double scaleX = 1.0;
    double scaleY = 1.0;

    if ((sumXX - n * avgX * avgX) > 1e-10) {
      scaleX = (sumXXp - n * avgX * avgXp) / (sumXX - n * avgX * avgX);
    }

    if ((sumYY - n * avgY * avgY) > 1e-10) {
      scaleY = (sumYYp - n * avgY * avgYp) / (sumYY - n * avgY * avgY);
    }

    final tx = avgXp - scaleX * avgX;
    final ty = avgYp - scaleY * avgY;

    _transform = AffineTransform(
      a: scaleX,
      b: 0.0,
      c: 0.0,
      d: scaleY,
      tx: tx,
      ty: ty,
    );

    _isCalibrated = true;
    print(
      'Kalibrasyon tamamlandı: scaleX=$scaleX, scaleY=$scaleY, tx=$tx, ty=$ty',
    );

    // Kalibrasyon hatasını hesapla
    double totalError = 0;
    for (final point in _calibrationPoints) {
      final (predX, predY) = _transform!.transform(
        point.measuredX,
        point.measuredY,
      );
      final errorX = predX - point.targetX;
      final errorY = predY - point.targetY;
      totalError += errorX * errorX + errorY * errorY;
    }
    final rmse = math.sqrt(totalError / n);
    print('Kalibrasyon RMSE: $rmse');

    return true;
  }

  /// GazeFrame'e kalibrasyon uygula
  GazeFrame applyCalibration(GazeFrame frame) {
    if (!_isCalibrated || _transform == null || !frame.valid) {
      return frame;
    }

    final (calibratedX, calibratedY) = _transform!.transform(frame.x, frame.y);

    // Sınırları kontrol et [0, 1]
    final clampedX = calibratedX.clamp(0.0, 1.0);
    final clampedY = calibratedY.clamp(0.0, 1.0);

    return frame.copyWith(x: clampedX, y: clampedY);
  }

  /// Kalibrasyonu dosyaya kaydet
  Future<void> saveCalibration() async {
    if (!_isCalibrated || _transform == null) {
      print('Kaydetmek için kalibrasyon yapılmamış');
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gaze_calibration.json');

      final data = {
        'transform': _transform!.toJson(),
        'points': _calibrationPoints.map((p) => p.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(data));
      print('Kalibrasyon kaydedildi: ${file.path}');
    } catch (e) {
      print('Kalibrasyon kaydedilemedi: $e');
    }
  }

  /// Kalibrasyonu dosyadan yükle
  Future<bool> loadCalibration() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gaze_calibration.json');

      if (!await file.exists()) {
        print('Kalibrasyon dosyası bulunamadı');
        return false;
      }

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);

      _transform = AffineTransform.fromJson(data['transform']);
      _calibrationPoints = (data['points'] as List)
          .map((p) => CalibrationPoint.fromJson(p))
          .toList();
      _isCalibrated = true;

      print('Kalibrasyon yüklendi (${data['timestamp']})');
      return true;
    } catch (e) {
      print('Kalibrasyon yüklenemedi: $e');
      return false;
    }
  }
}
