import 'dart:async';
import 'package:flutter/services.dart';
import 'gaze_models.dart';

/// iOS native tarafıyla iletişim kuran MethodChannel sarmalayıcı
class GazeChannel {
  static const String _channelName = 'gaze';
  static const MethodChannel _channel = MethodChannel(_channelName);

  // Frame stream controller
  final StreamController<GazeFrame> _frameController =
      StreamController<GazeFrame>.broadcast();

  /// Gelen frame'leri dinlemek için stream
  Stream<GazeFrame> get onFrameStream => _frameController.stream;

  /// Takip aktif mi?
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  GazeChannel() {
    _setupMethodCallHandler();
  }

  /// Native taraftan gelen method çağrılarını dinle
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFrame':
          // Native taraftan gelen frame verisi
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            call.arguments,
          );
          final frame = GazeFrame.fromJson(data);
          _frameController.add(frame);
          break;
        default:
          print('Bilinmeyen method çağrısı: ${call.method}');
      }
    });
  }

  /// Gaze takibini başlat
  Future<void> start() async {
    if (_isTracking) {
      print('Gaze takibi zaten aktif');
      return;
    }

    try {
      await _channel.invokeMethod('start');
      _isTracking = true;
      print('Gaze takibi başlatıldı');
    } catch (e) {
      print('Gaze takibi başlatılamadı: $e');
      rethrow;
    }
  }

  /// Gaze takibini durdur
  Future<void> stop() async {
    if (!_isTracking) {
      print('Gaze takibi zaten pasif');
      return;
    }

    try {
      await _channel.invokeMethod('stop');
      _isTracking = false;
      print('Gaze takibi durduruldu');
    } catch (e) {
      print('Gaze takibi durdurulamadı: $e');
      rethrow;
    }
  }

  /// Temizlik
  void dispose() {
    if (_isTracking) {
      stop();
    }
    _frameController.close();
  }
}
