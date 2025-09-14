import 'package:flutter/material.dart';
import '../gaze/gaze_channel.dart';
import '../gaze/gaze_models.dart';
import '../gaze/gaze_filter.dart';
import '../overlay/gaze_overlay.dart';
import '../calibration/calibration_screen.dart';
import '../calibration/calibration_service.dart';
import 'mode_select_screen.dart';

class StudyScreen extends StatefulWidget {
  final StudyMode mode;
  const StudyScreen({super.key, required this.mode});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final GazeChannel _gazeChannel = GazeChannel();
  final CalibrationService _calibrationService = CalibrationService();

  // Smoothing filter
  late OneEuroFilter2D _filter2d;

  GazeFrame? _filteredFrame;
  bool _isTracking = false;
  int _focusedMs = 0;
  int _driftingMs = 0;
  int _distractCount = 0;
  DateTime? _lastTick;

  bool _isFocused = false;
  int _transitionMs = 0; // debounce for state changes

  static const int attentionThresholdMs = 10000; // 10s
  static const int stateDebounceMs = 500; // 0.5s

  // Phone mode safe margins to avoid edge flicker
  static const double margin = 0.06; // 6% kenar boşluğu

  @override
  void initState() {
    super.initState();
    _calibrationService.loadCalibration();
    _filter2d = OneEuroFilter2D(
      frequency: 60.0,
      minCutoff: 1.0,
      beta: 0.01, // daha stabil (öncekinden daha düşük)
      dCutoff: 1.0,
    );
    _gazeChannel.onFrameStream.listen(_onFrame);
  }

  void _onFrame(GazeFrame frame) {
    final calibrated = _calibrationService.applyCalibration(frame);

    GazeFrame? filtered;
    if (calibrated.valid) {
      final (fx, fy) = _filter2d.filter(
        calibrated.x,
        calibrated.y,
        calibrated.timestamp / 1000.0,
      );
      filtered = calibrated.copyWith(x: fx, y: fy);
    }

    setState(() {
      _filteredFrame = (filtered != null && filtered.valid) ? filtered : null;
    });
    _tickState();
  }

  void _tickState() {
    final now = DateTime.now();
    _lastTick ??= now;
    final delta = now.difference(_lastTick!).inMilliseconds;
    _lastTick = now;

    final desiredFocused = _computeFocusedNow();

    if (desiredFocused != _isFocused) {
      _transitionMs += delta;
      if (_transitionMs >= stateDebounceMs) {
        _isFocused = desiredFocused;
        _transitionMs = 0;
      }
    } else {
      _transitionMs = 0;
    }

    if (_isFocused) {
      _focusedMs += delta;
      _driftingMs = 0; // reset window while focused
    } else {
      _driftingMs += delta;
      if (_driftingMs >= attentionThresholdMs) {
        _distractCount += 1;
        _driftingMs = 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dikkat dağıldı (${widget.mode.name})')),
          );
        }
      }
    }

    if (mounted) setState(() {});
  }

  bool _computeFocusedNow() {
    final f = _filteredFrame;
    if (!_isTracking || f == null || !f.valid || f.confidence < 0.5)
      return false;

    // Ekran içi alan — kenarlarda margin uygula
    final inScreen =
        f.x >= margin &&
        f.x <= 1.0 - margin &&
        f.y >= margin &&
        f.y <= 1.0 - margin;

    switch (widget.mode) {
      case StudyMode.phone:
        return inScreen;
      case StudyMode.book:
        // Geçici kitap alanı: alt-orta band (landscape için yine y alta yakın)
        const bottomNear = 0.90;
        const centerBandL = 0.40;
        const centerBandR = 0.60;
        final inBook =
            (f.y >= bottomNear) && (f.x >= centerBandL && f.x <= centerBandR);
        return inBook;
      case StudyMode.hybrid:
        const bottomNear = 0.90;
        const centerBandL = 0.40;
        const centerBandR = 0.60;
        final inBook =
            (f.y >= bottomNear) && (f.x >= centerBandL && f.x <= centerBandR);
        return inScreen || inBook;
    }
  }

  Future<void> _toggle() async {
    if (_isTracking) {
      await _gazeChannel.stop();
    } else {
      await _gazeChannel.start();
      _lastTick = DateTime.now();
    }
    setState(() => _isTracking = !_isTracking);
  }

  Future<void> _openCalibration() async {
    if (_isTracking) await _gazeChannel.stop();
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalibrationScreen(
          gazeChannel: _gazeChannel,
          calibrationService: _calibrationService,
        ),
      ),
    );
    if (res == true && !_isTracking) {
      await _gazeChannel.start();
      setState(() => _isTracking = true);
    }
  }

  @override
  void dispose() {
    if (_isTracking) {
      _gazeChannel.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Çalışma — ${widget.mode.name}'),
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _openCalibration),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_filteredFrame != null && _filteredFrame!.valid)
                    GazeOverlay(gazeFrame: _filteredFrame!),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ElevatedButton.icon(
                        onPressed: _toggle,
                        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                        label: Text(_isTracking ? 'Durdur' : 'Başlat'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Durum: ${_isTracking ? (_isFocused ? 'Focused' : 'Drifting') : 'Pasif'}',
                  ),
                  const SizedBox(height: 8),
                  Text('Focused (ms): $_focusedMs'),
                  Text('Drifting (ms): $_driftingMs'),
                  Text('Uyarı sayısı: $_distractCount'),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Bitir'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
