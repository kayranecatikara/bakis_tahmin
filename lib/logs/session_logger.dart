import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../gaze/gaze_models.dart';

/// Session loglama servisi
class SessionLogger {
  File? _currentLogFile;
  IOSink? _logSink;
  DateTime? _sessionStartTime;
  int _frameCount = 0;

  bool get isLogging => _logSink != null;

  /// Yeni bir loglama oturumu başlat
  Future<void> startSession() async {
    if (isLogging) {
      print('Loglama zaten aktif');
      return;
    }

    try {
      // Log dizinini oluştur
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/gaze_logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Log dosyası adı (timestamp ile)
      _sessionStartTime = DateTime.now();
      final timestamp = _sessionStartTime!.toIso8601String().replaceAll(
        ':',
        '-',
      );
      final fileName = 'gaze_session_$timestamp.jsonl';
      _currentLogFile = File('${logDir.path}/$fileName');

      // Dosyayı aç
      _logSink = _currentLogFile!.openWrite();
      _frameCount = 0;

      // Session başlangıç bilgisini yaz
      final sessionInfo = {
        'type': 'session_start',
        'timestamp': _sessionStartTime!.toIso8601String(),
        'device': {
          'platform': 'iOS',
          'model': 'iPhone', // TODO: Gerçek model bilgisi
        },
      };
      _logSink!.writeln(jsonEncode(sessionInfo));

      print('Loglama başlatıldı: ${_currentLogFile!.path}');
    } catch (e) {
      print('Loglama başlatılamadı: $e');
      _logSink = null;
      _currentLogFile = null;
    }
  }

  /// Frame'i logla
  void logFrame(GazeFrame frame) {
    if (!isLogging) return;

    try {
      final logEntry = {
        'type': 'gaze_frame',
        'frame_number': _frameCount++,
        'timestamp': frame.timestamp,
        'x': frame.x,
        'y': frame.y,
        'confidence': frame.confidence,
        'valid': frame.valid,
      };

      _logSink!.writeln(jsonEncode(logEntry));
    } catch (e) {
      print('Frame loglanamadı: $e');
    }
  }

  /// Özel event logla
  void logEvent(String eventType, Map<String, dynamic> data) {
    if (!isLogging) return;

    try {
      final logEntry = {
        'type': 'event',
        'event_type': eventType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      };

      _logSink!.writeln(jsonEncode(logEntry));
    } catch (e) {
      print('Event loglanamadı: $e');
    }
  }

  /// Loglama oturumunu sonlandır
  Future<void> endSession() async {
    if (!isLogging) return;

    try {
      // Session bitiş bilgisini yaz
      final sessionEnd = {
        'type': 'session_end',
        'timestamp': DateTime.now().toIso8601String(),
        'duration_ms': DateTime.now()
            .difference(_sessionStartTime!)
            .inMilliseconds,
        'total_frames': _frameCount,
      };
      _logSink!.writeln(jsonEncode(sessionEnd));

      // Dosyayı kapat
      await _logSink!.flush();
      await _logSink!.close();

      print('Loglama sonlandırıldı. Toplam frame: $_frameCount');

      // Temizle
      _logSink = null;
      _currentLogFile = null;
      _sessionStartTime = null;
      _frameCount = 0;
    } catch (e) {
      print('Loglama sonlandırılamadı: $e');
    }
  }

  /// Log dosyalarını listele
  Future<List<FileSystemEntity>> listLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/gaze_logs');

      if (!await logDir.exists()) {
        return [];
      }

      final files = await logDir.list().toList();
      files.sort((a, b) => b.path.compareTo(a.path)); // En yeni önce
      return files;
    } catch (e) {
      print('Log dosyaları listelenemedi: $e');
      return [];
    }
  }

  /// Tüm log dosyalarını sil
  Future<void> clearAllLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/gaze_logs');

      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
        print('Tüm loglar silindi');
      }
    } catch (e) {
      print('Loglar silinemedi: $e');
    }
  }

  /// Log dosyasının boyutunu al (MB)
  Future<double?> getCurrentLogSize() async {
    if (_currentLogFile == null) return null;

    try {
      final stat = await _currentLogFile!.stat();
      return stat.size / (1024 * 1024); // MB cinsinden
    } catch (e) {
      return null;
    }
  }
}
