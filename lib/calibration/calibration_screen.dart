import 'dart:async';
import 'package:flutter/material.dart';
import '../gaze/gaze_channel.dart';
import '../gaze/gaze_models.dart';
import 'calibration_service.dart';

/// Kalibrasyon ekranı - 9 noktalı kalibrasyon sihirbazı
class CalibrationScreen extends StatefulWidget {
  final GazeChannel gazeChannel;
  final CalibrationService calibrationService;

  const CalibrationScreen({
    super.key,
    required this.gazeChannel,
    required this.calibrationService,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // Kalibrasyon noktaları (3x3 grid)
  static const List<(double, double)> _calibrationTargets = [
    (0.1, 0.1), (0.5, 0.1), (0.9, 0.1), // Üst satır
    (0.1, 0.5), (0.5, 0.5), (0.9, 0.5), // Orta satır
    (0.1, 0.9), (0.5, 0.9), (0.9, 0.9), // Alt satır
  ];

  int _currentPointIndex = 0;
  bool _isCollecting = false;
  bool _isCalibrating = false;
  List<GazeFrame> _collectedFrames = [];
  StreamSubscription<GazeFrame>? _gazeSubscription;

  // Toplama parametreleri
  static const int _framesPerPoint = 60; // Her nokta için 60 frame topla
  static const Duration _settleTime = Duration(
    milliseconds: 1000,
  ); // Yerleşme süresi

  @override
  void initState() {
    super.initState();
    _startCalibration();
  }

  @override
  void dispose() {
    _gazeSubscription?.cancel();
    widget.gazeChannel.stop();
    super.dispose();
  }

  Future<void> _startCalibration() async {
    // Önceki kalibrasyonu temizle
    widget.calibrationService.clearCalibrationPoints();

    // Gaze takibini başlat
    await widget.gazeChannel.start();

    // Frame dinleyicisini kur
    _gazeSubscription = widget.gazeChannel.onFrameStream.listen(_onGazeFrame);

    setState(() {
      _isCalibrating = true;
      _currentPointIndex = 0;
    });

    // İlk nokta için veri toplamaya başla
    _startCollectingForCurrentPoint();
  }

  void _startCollectingForCurrentPoint() async {
    if (_currentPointIndex >= _calibrationTargets.length) {
      _finishCalibration();
      return;
    }

    // Yerleşme süresi
    await Future.delayed(_settleTime);

    setState(() {
      _isCollecting = true;
      _collectedFrames.clear();
    });
  }

  void _onGazeFrame(GazeFrame frame) {
    if (!_isCollecting || !frame.valid) return;

    _collectedFrames.add(frame);

    // Yeterli frame toplandıysa artık otomatik geçme yok; butonla ilerle
    // Sadece biriktirmeye devam ediyoruz
  }

  void _processCollectedFrames() {
    if (_collectedFrames.isEmpty) return;

    // Ortalama pozisyonu hesapla
    double avgX = 0, avgY = 0;
    int validCount = 0;

    for (final frame in _collectedFrames) {
      if (frame.valid) {
        avgX += frame.x;
        avgY += frame.y;
        validCount++;
      }
    }

    if (validCount > 0) {
      avgX /= validCount;
      avgY /= validCount;

      // Hedef nokta
      final target = _calibrationTargets[_currentPointIndex];

      // Kalibrasyon noktası ekle
      widget.calibrationService.addCalibrationPoint(
        CalibrationPoint(
          measuredX: avgX,
          measuredY: avgY,
          targetX: target.$1,
          targetY: target.$2,
        ),
      );

      print(
        'Kalibrasyon noktası $_currentPointIndex: '
        'Ölçülen($avgX, $avgY) -> Hedef(${target.$1}, ${target.$2})',
      );
    }

    // Sonraki noktaya geç
    setState(() {
      _isCollecting = false;
      _currentPointIndex++;
    });

    _startCollectingForCurrentPoint();
  }

  void _finishCalibration() async {
    setState(() {
      _isCalibrating = false;
    });

    // Dönüşümü hesapla
    final success = widget.calibrationService.calculateTransform();

    if (success) {
      // Kalibrasyonu kaydet
      await widget.calibrationService.saveCalibration();

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kalibrasyon başarıyla tamamlandı!'),
            backgroundColor: Colors.green,
          ),
        );

        // Ana ekrana dön
        Navigator.pop(context, true);
      }
    } else {
      // Hata mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kalibrasyon başarısız! Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );

        // Tekrar başlat
        _startCalibration();
      }
    }
  }

  void _skipPoint() {
    setState(() {
      _isCollecting = false;
      _currentPointIndex++;
    });
    _startCollectingForCurrentPoint();
  }

  void _cancelCalibration() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          // Kalibrasyon noktaları
          if (_isCalibrating && _currentPointIndex < _calibrationTargets.length)
            ..._buildCalibrationPoints(size),

          // Üst bilgi çubuğu
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Kalibrasyon - Nokta ${_currentPointIndex + 1}/${_calibrationTargets.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCollecting
                          ? 'Lütfen kırmızı noktaya bakın. Yeterli örnek toplandığında alttan Kaydet ve Sonraki’ye basın.'
                          : 'Sonraki noktaya hazırlanıyor...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (_isCollecting) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _collectedFrames.length / _framesPerPoint,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Alt kontrol butonları
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _cancelCalibration,
                      child: const Text(
                        'İptal',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    if (_isCollecting)
                      TextButton(
                        onPressed: _skipPoint,
                        child: const Text(
                          'Atla',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    if (_isCollecting &&
                        _collectedFrames.length >= _framesPerPoint)
                      ElevatedButton.icon(
                        onPressed: _processCollectedFrames,
                        icon: const Icon(Icons.check),
                        label: const Text('Kaydet ve Sonraki'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalibrationPoints(Size screenSize) {
    final widgets = <Widget>[];

    for (int i = 0; i < _calibrationTargets.length; i++) {
      final target = _calibrationTargets[i];
      final isActive = i == _currentPointIndex;
      final isDone = i < _currentPointIndex;

      widgets.add(
        Positioned(
          left: target.$1 * screenSize.width - 20,
          top: target.$2 * screenSize.height - 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.red
                  : isDone
                  ? Colors.green.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.white : Colors.white30,
                width: isActive ? 3 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
