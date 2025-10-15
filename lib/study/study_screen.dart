import 'package:flutter/material.dart';
import '../gaze/gaze_channel.dart';
import '../gaze/gaze_models.dart';
import '../gaze/gaze_filter.dart';
import '../overlay/gaze_overlay.dart';
import '../calibration/calibration_screen.dart';
import '../calibration/calibration_service.dart';
import '../logs/session_logger.dart';
import '../reports/session_result_screen.dart';
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
  final SessionLogger _sessionLogger = SessionLogger();

  // Smoothing filter
  late OneEuroFilter2D _filter2d;

  GazeFrame? _filteredFrame;
  bool _isTracking = false;
  int _focusedMs = 0;
  int _driftingMs = 0;
  int _distractCount = 0;
  DateTime? _sessionStart;
  DateTime? _lastTick;

  bool _isFocused = false;
  int _transitionMs = 0; // debounce for state changes

  // Timeline tracking: zaman bazlı odak durumu
  final List<Map<String, dynamic>> _focusTimeline = [];
  DateTime? _lastTimelineRecord;
  static const int timelineRecordIntervalMs = 1000; // her saniye kaydet

  static const int attentionThresholdMs = 10000; // 10s
  static const int stateDebounceMs = 500; // 0.5s

  // Phone mode safe margins to avoid edge flicker
  static const double margin = 0.06; // 6% kenar boşluğu

  // Zone definitions (normalized, landscape). Can be made configurable later.
  // Screen zone: top-middle rectangle (x: 0.25..0.75, y: 0.08..0.40)
  static const double screenXMin = 0.25;
  static const double screenXMax = 0.75;
  static const double screenYMin = 0.08;
  static const double screenYMax = 0.40;
  // Book zone: bottom wide band under the phone (x: 0.06..0.94, y >= 0.60)
  static const double bookXMin = 0.06;
  static const double bookXMax = 0.94;
  static const double bookYMin = 0.60;

  // Head pitch thresholds (radians). Negative = head down.
  static const double pitchBookDown =
      -0.15; // <= this → likely looking down to book
  static const double pitchPhoneUp = 0.20; // >= this → likely away from phone

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
        // Log warning event
        _sessionLogger.logEvent('warning', {
          'mode': widget.mode.name,
          'focusedMs': _focusedMs,
          'distractCount': _distractCount,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dikkat dağıldı (${widget.mode.name})')),
          );
        }
      }
    }

    // Timeline kaydı: her saniye odak durumunu kaydet
    _lastTimelineRecord ??= now;
    if (now.difference(_lastTimelineRecord!).inMilliseconds >=
        timelineRecordIntervalMs) {
      final timelinePoint = {
        'timestamp': now.millisecondsSinceEpoch,
        'focused': _isFocused,
        'elapsedMs': _focusedMs + _driftingMs,
      };
      _focusTimeline.add(timelinePoint);
      // JSONL'a da kaydet
      _sessionLogger.logEvent('focus_state', timelinePoint);
      _lastTimelineRecord = now;
    }

    if (mounted) setState(() {});
  }

  bool _computeFocusedNow() {
    final f = _filteredFrame;
    if (!_isTracking || f == null || !f.valid || f.confidence < 0.5)
      return false;

    // Ekran içi alan — kenarlarda margin uygula
    final inScreenSafe =
        f.x >= margin &&
        f.x <= 1.0 - margin &&
        f.y >= margin &&
        f.y <= 1.0 - margin;
    // Top-middle screen rect
    final inScreenRect =
        f.x >= screenXMin &&
        f.x <= screenXMax &&
        f.y >= screenYMin &&
        f.y <= screenYMax;
    // Bottom-wide book band
    final inBookBand = f.x >= bookXMin && f.x <= bookXMax && f.y >= bookYMin;

    final hp = f.headPitch; // may be null

    switch (widget.mode) {
      case StudyMode.phone:
        final screenOk = inScreenRect && inScreenSafe;
        final pitchOk = hp == null
            ? true
            : hp < pitchPhoneUp; // baş çok yukarıysa uzaklaşıyor
        return screenOk && pitchOk;
      case StudyMode.book:
        final bandOk = inBookBand;
        // Pitch sadece ekran dikdörtgeninin DIŞINDAYSAN devreye girsin (fallback)
        final pitchDownFallback =
            (hp != null && hp <= pitchBookDown) && !inScreenRect;
        return bandOk || pitchDownFallback;
      case StudyMode.hybrid:
        final screenOkH =
            inScreenRect &&
            inScreenSafe &&
            (hp == null ? true : hp < pitchPhoneUp);
        final bookOkH =
            inBookBand ||
            ((hp != null && hp <= pitchBookDown) && !inScreenRect);
        return screenOkH || bookOkH;
    }
  }

  Future<void> _toggle() async {
    if (_isTracking) {
      await _gazeChannel.stop();
      await _finishSession();
    } else {
      await _gazeChannel.start();
      _sessionStart = DateTime.now();
      _lastTick = DateTime.now();
      _focusedMs = 0;
      _driftingMs = 0;
      _distractCount = 0;
      _focusTimeline.clear();
      _lastTimelineRecord = null;
      await _sessionLogger.startSession();
      _sessionLogger.logEvent('session_start', {'mode': widget.mode.name});
    }
    setState(() => _isTracking = !_isTracking);
  }

  Future<void> _finishSession() async {
    if (_sessionStart == null) return;
    final duration = DateTime.now().difference(_sessionStart!).inMilliseconds;
    final focusRatio = duration > 0 ? (_focusedMs / duration) : 0.0;
    _sessionLogger.logEvent('session_end', {
      'mode': widget.mode.name,
      'durationMs': duration,
      'focusedMs': _focusedMs,
      'driftingMs': _driftingMs,
      'distractCount': _distractCount,
      'focusRatio': focusRatio,
    });
    await _sessionLogger.endSession();
    _sessionStart = null;
  }

  Future<void> _openCalibration() async {
    if (_isTracking) {
      await _gazeChannel.stop();
      await _finishSession();
      setState(() => _isTracking = false);
    }
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
      // Optionally auto-restart after calibration
    }
  }

  Future<void> _finishAndExit() async {
    if (_isTracking) {
      await _gazeChannel.stop();
      await _finishSession();
    }

    // Oturum verilerini topla ve sonuç ekranına git
    if (mounted && _sessionStart != null) {
      final duration = DateTime.now().difference(_sessionStart!).inMilliseconds;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionResultScreen(
            mode: widget.mode.name,
            durationMs: duration,
            focusedMs: _focusedMs,
            distractCount: _distractCount,
            focusTimeline: List.from(_focusTimeline),
          ),
        ),
      );
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    if (_isTracking) {
      _gazeChannel.stop();
      _sessionLogger.endSession();
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
                  if (_filteredFrame?.headPitch != null)
                    Text(
                      'Pitch: ${_filteredFrame!.headPitch!.toStringAsFixed(3)} rad',
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _finishAndExit,
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
