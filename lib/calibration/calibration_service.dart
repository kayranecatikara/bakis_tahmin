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
  AffineTransform? get transform => _transform;

  void addCalibrationPoint(CalibrationPoint point) {
    _calibrationPoints.add(point);
  }

  void clearCalibrationPoints() {
    _calibrationPoints.clear();
    _transform = null;
    _isCalibrated = false;
  }

  // Çöz: 3x3 lineer sistem (Gaussian elimination, küçük boyut)
  List<double>? _solve3x3(List<List<double>> A, List<double> b) {
    // Augmented matrix [A|b]
    final m = List.generate(3, (i) => List<double>.from(A[i])..add(b[i]));
    const eps = 1e-12;

    // Forward elimination with partial pivoting
    for (int col = 0; col < 3; col++) {
      // Pivot seç
      int pivot = col;
      double maxAbs = m[col][col].abs();
      for (int r = col + 1; r < 3; r++) {
        final v = m[r][col].abs();
        if (v > maxAbs) {
          maxAbs = v;
          pivot = r;
        }
      }
      if (maxAbs < eps) return null; // singular
      if (pivot != col) {
        final tmp = m[col];
        m[col] = m[pivot];
        m[pivot] = tmp;
      }
      // Normalize pivot row
      final div = m[col][col];
      for (int k = col; k < 4; k++) {
        m[col][k] /= div;
      }
      // Eliminate others
      for (int r = 0; r < 3; r++) {
        if (r == col) continue;
        final factor = m[r][col];
        for (int k = col; k < 4; k++) {
          m[r][k] -= factor * m[col][k];
        }
      }
    }
    return [m[0][3], m[1][3], m[2][3]];
  }

  /// Afine dönüşüm hesapla (en küçük kareler). En az 5 nokta önerilir.
  bool calculateTransform() {
    final n = _calibrationPoints.length;
    if (n < 3) {
      print('Kalibrasyon için en az 3 nokta gerekli (öneri: 9).');
      return false;
    }

    // Tasarım matrisi X: [xi yi 1]
    // x' = [a b tx] · X^T ; y' = [c d ty] · X^T
    double sX = 0, sY = 0, s1 = n.toDouble();
    double sXX = 0, sYY = 0, sXY = 0;

    double sXxP = 0, sYxP = 0, sxP = 0; // bilesenler (x prime için)
    double sXyP = 0, sYyP = 0, syP = 0; // bilesenler (y prime için)

    for (final p in _calibrationPoints) {
      final x = p.measuredX;
      final y = p.measuredY;
      final xp = p.targetX;
      final yp = p.targetY;
      sX += x;
      sY += y;
      sXX += x * x;
      sYY += y * y;
      sXY += x * y;
      sXxP += x * xp;
      sYxP += y * xp;
      sxP += xp;
      sXyP += x * yp;
      sYyP += y * yp;
      syP += yp;
    }

    // Normal denklemler: [Sxx Sxy Sx; Sxy Syy Sy; Sx Sy N] * [a b tx] = [sum(x*X') sum(y*X') sum(X')]
    final A = [
      [sXX, sXY, sX],
      [sXY, sYY, sY],
      [sX, sY, s1],
    ];

    final solX = _solve3x3(A, [sXxP, sYxP, sxP]);
    final solY = _solve3x3(A, [sXyP, sYyP, syP]);
    if (solX == null || solY == null) {
      print(
        'Kalibrasyon çözülemedi (singular). Nokta dağılımını kontrol edin.',
      );
      return false;
    }

    final a = solX[0], b = solX[1], tx = solX[2];
    final c = solY[0], d = solY[1], ty = solY[2];
    _transform = AffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty);

    // Hata ölçümü (RMSE)
    double sse = 0;
    for (final p in _calibrationPoints) {
      final pred = _transform!.transform(p.measuredX, p.measuredY);
      final dx = pred.$1 - p.targetX;
      final dy = pred.$2 - p.targetY;
      sse += dx * dx + dy * dy;
    }
    final rmse = (sse / n).sqrt();
    print(
      'Kalibrasyon tamamlandı: a=$a, b=$b, c=$c, d=$d, tx=$tx, ty=$ty, RMSE=$rmse',
    );

    _isCalibrated = true;
    return true;
  }

  GazeFrame applyCalibration(GazeFrame frame) {
    if (!_isCalibrated || _transform == null || !frame.valid) {
      return frame;
    }
    final (cx, cy) = _transform!.transform(frame.x, frame.y);
    final nx = cx.clamp(0.0, 1.0);
    final ny = cy.clamp(0.0, 1.0);
    return frame.copyWith(x: nx, y: ny);
  }

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

extension MathExtensions on double {
  double sqrt() => this <= 0 ? 0 : MathHelper.sqrt(this);
}

class MathHelper {
  // Basit Newton yöntemi karekök
  static double sqrt(double v) {
    double x = v;
    double last = 0;
    for (int i = 0; i < 20; i++) {
      last = x;
      x = 0.5 * (x + v / x);
      if ((x - last).abs() < 1e-12) break;
    }
    return x;
  }
}
