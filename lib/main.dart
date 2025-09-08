import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gaze/gaze_channel.dart';
import 'gaze/gaze_models.dart';
import 'gaze/gaze_filter.dart';
import 'overlay/gaze_overlay.dart';
import 'calibration/calibration_screen.dart';
import 'calibration/calibration_service.dart';
import 'logs/session_logger.dart';

void main() {
  runApp(const FocusGuardGazeApp());
}

class FocusGuardGazeApp extends StatelessWidget {
  const FocusGuardGazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusGuard Gaze',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GazeMainScreen(),
    );
  }
}

class GazeMainScreen extends StatefulWidget {
  const GazeMainScreen({super.key});

  @override
  State<GazeMainScreen> createState() => _GazeMainScreenState();
}

class _GazeMainScreenState extends State<GazeMainScreen> {
  // Gaze takip durumu
  bool _isTracking = false;
  bool _showOverlay = true;
  bool _isLogging = false;

  // Gaze verileri
  GazeFrame? _currentFrame;
  GazeFrame? _filteredFrame;

  // Servisler
  final GazeChannel _gazeChannel = GazeChannel();
  final CalibrationService _calibrationService = CalibrationService();
  final SessionLogger _sessionLogger = SessionLogger();
  late OneEuroFilter _filterX;
  late OneEuroFilter _filterY;

  String _gazeZone = '—';
  String _classifyZone(GazeFrame f) {
    if (!f.valid) return 'Dışarısı';
    final x = f.x;
    final y = f.y;
    final inside = x >= 0.0 && x <= 1.0 && y >= 0.0 && y <= 1.0;
    if (!inside) return 'Dışarısı';
    if (y > 0.85) return 'Kitap';
    return 'Ekran';
  }

  // Performans metrikleri
  int _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _loadCalibration();
    _setupGazeListener();
  }

  void _initializeFilters() {
    // 1-Euro filtre parametreleri (ayarlanabilir)
    _filterX = OneEuroFilter(
      frequency: 60.0,
      minCutoff: 1.0,
      beta: 0.5,
      dCutoff: 1.0,
    );
    _filterY = OneEuroFilter(
      frequency: 60.0,
      minCutoff: 1.0,
      beta: 0.5,
      dCutoff: 1.0,
    );
  }

  Future<void> _loadCalibration() async {
    await _calibrationService.loadCalibration();
  }

  void _setupGazeListener() {
    _gazeChannel.onFrameStream.listen((frame) {
      if (!mounted) return;

      // FPS hesaplama
      _frameCount++;
      final now = DateTime.now();
      if (now.difference(_lastFpsUpdate).inSeconds >= 1) {
        setState(() {
          _fps = _frameCount;
          _frameCount = 0;
          _lastFpsUpdate = now;
        });
      }

      // Kalibrasyon uygula
      final calibratedFrame = _calibrationService.applyCalibration(frame);

      // Filtre uygula
      if (calibratedFrame.valid) {
        final filteredX = _filterX.filter(
          calibratedFrame.x,
          calibratedFrame.timestamp / 1000.0,
        );
        final filteredY = _filterY.filter(
          calibratedFrame.y,
          calibratedFrame.timestamp / 1000.0,
        );

        final filtered = GazeFrame(
          x: filteredX,
          y: filteredY,
          confidence: calibratedFrame.confidence,
          timestamp: calibratedFrame.timestamp,
          valid: calibratedFrame.valid,
        );

        setState(() {
          _currentFrame = calibratedFrame;
          _filteredFrame = filtered;
        });

        // Bölge sınıflandırma
        final zone = _classifyZone(filtered);
        setState(() {
          _currentFrame = calibratedFrame;
          _filteredFrame = filtered;
          _gazeZone = zone;
        });
        // Loglama
        if (_isLogging) {
          _sessionLogger.logFrame(filtered);
        }
      } else {
        setState(() {
          _currentFrame = calibratedFrame;
          _filteredFrame = null;
          _gazeZone = 'Dışarısı';
        });
      }
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _gazeChannel.stop();
      if (_isLogging) {
        await _sessionLogger.endSession();
      }
    } else {
      await _gazeChannel.start();
      if (_isLogging) {
        await _sessionLogger.startSession();
      }
    }

    setState(() {
      _isTracking = !_isTracking;
    });
  }

  Future<void> _startCalibration() async {
    // Takibi durdur
    if (_isTracking) {
      await _toggleTracking();
    }

    if (!mounted) return;

    // Kalibrasyon ekranına git
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalibrationScreen(
          gazeChannel: _gazeChannel,
          calibrationService: _calibrationService,
        ),
      ),
    );

    // Kalibrasyon tamamlandıysa filtreleri sıfırla
    if (result == true) {
      _initializeFilters();
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  void _toggleLogging() async {
    if (_isLogging) {
      await _sessionLogger.endSession();
    } else if (_isTracking) {
      await _sessionLogger.startSession();
    }

    setState(() {
      _isLogging = !_isLogging;
    });
  }

  @override
  void dispose() {
    if (_isTracking) {
      _gazeChannel.stop();
    }
    if (_isLogging) {
      _sessionLogger.endSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ana UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık
                  const Text(
                    'FocusGuard Gaze Tracker',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Durum kartı
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Durum: ${_isTracking ? "Aktif" : "Pasif"}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('FPS: $_fps'),
                          Text(
                            'Geçerli Frame: ${_currentFrame?.valid ?? false ? "Evet" : "Hayır"}',
                          ),
                          Text('Bölge: $_gazeZone'),
                          if (_currentFrame != null &&
                              _currentFrame!.valid) ...[
                            Text('X: ${_currentFrame!.x.toStringAsFixed(3)}'),
                            Text('Y: ${_currentFrame!.y.toStringAsFixed(3)}'),
                            Text(
                              'Güven: ${(_currentFrame!.confidence * 100).toStringAsFixed(1)}%',
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Kalibrasyon: ${_calibrationService.isCalibrated ? "Yapıldı" : "Yapılmadı"}',
                            style: TextStyle(
                              color: _calibrationService.isCalibrated
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ana kontroller
                  ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isTracking ? 'Takibi Durdur' : 'Takibi Başlat',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _startCalibration,
                    icon: const Icon(Icons.tune),
                    label: const Text('Kalibrasyon Başlat'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ek kontroller
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Overlay'),
                          value: _showOverlay,
                          onChanged: (value) => _toggleOverlay(),
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Loglama'),
                          value: _isLogging,
                          onChanged: (value) => _toggleLogging(),
                          dense: true,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Filtre ayarları
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1-Euro Filtre Ayarları',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Min Cutoff: ${_filterX.minCutoff.toStringAsFixed(2)}',
                          ),
                          Slider(
                            value: _filterX.minCutoff,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            label: _filterX.minCutoff.toStringAsFixed(2),
                            onChanged: (value) {
                              setState(() {
                                _filterX.minCutoff = value;
                                _filterY.minCutoff = value;
                              });
                            },
                          ),
                          Text('Beta: ${_filterX.beta.toStringAsFixed(2)}'),
                          Slider(
                            value: _filterX.beta,
                            min: 0.0,
                            max: 2.0,
                            divisions: 40,
                            label: _filterX.beta.toStringAsFixed(2),
                            onChanged: (value) {
                              setState(() {
                                _filterX.beta = value;
                                _filterY.beta = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gaze overlay
          if (_showOverlay && _filteredFrame != null && _filteredFrame!.valid)
            GazeOverlay(gazeFrame: _filteredFrame!),
        ],
      ),
    );
  }
}
