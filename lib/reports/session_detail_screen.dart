import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'reports_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final String fileName;
  final SessionSummary summary;

  const SessionDetailScreen({
    super.key,
    required this.fileName,
    required this.summary,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _focusTimeline = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/gaze_logs/${widget.fileName}');
      if (await logFile.exists()) {
        final lines = await logFile.readAsLines();
        final events = <Map<String, dynamic>>[];
        final timeline = <Map<String, dynamic>>[];
        
        for (final line in lines) {
          final json = jsonDecode(line) as Map<String, dynamic>;
          if (json['type'] == 'event') {
            events.add(json);
            // Focus timeline verilerini topla (focus_state event'leri)
            if (json['event_type'] == 'focus_state') {
              final data = json['data'] as Map<String, dynamic>?;
              if (data != null) {
                timeline.add({
                  'timestamp': json['timestamp'] as int,
                  'focused': data['focused'] as bool,
                  'elapsedMs': data['elapsedMs'] as int,
                });
              }
            }
          }
        }
        
        setState(() {
          _events = events;
          _focusTimeline = timeline;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oturum Detayları')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _buildChart(),
                  const SizedBox(height: 16),
                  _buildEventsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Özet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Mod: ${widget.summary.mode}'),
            Text('Tarih: ${_formatDate(widget.summary.sessionStart)}'),
            Text('Süre: ${_formatDuration(widget.summary.durationMs)}'),
            Text('Odak Oranı: ${(widget.summary.focusRatio * 100).toStringAsFixed(1)}%'),
            Text('Dikkat Dağılma: ${widget.summary.distractCount} kez'),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_focusTimeline.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Zaman çizelgesi verisi mevcut değil.'),
        ),
      );
    }

    // Timeline verisini LineChart için dönüştür
    final spots = <FlSpot>[];
    final startTime = _focusTimeline.first['timestamp'] as int;
    
    for (final point in _focusTimeline) {
      final timestamp = point['timestamp'] as int;
      final focused = point['focused'] as bool;
      final elapsedSec = (timestamp - startTime) / 1000.0;
      spots.add(FlSpot(elapsedSec, focused ? 1.0 : 0.0));
    }

    final durationMs = widget.summary.durationMs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dikkat Zaman Çizelgesi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yeşil: Odaklanmış | Kırmızı: Dağılmış',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: -0.1,
                  maxY: 1.1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Zaman (saniye)'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (durationMs / 1000 / 5).ceilToDouble().clamp(10, 60),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('Dağılmış');
                          if (value == 1) return const Text('Odaklı');
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.3),
                            Colors.red.withOpacity(0.3),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 0.5],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final sec = spot.x.toStringAsFixed(0);
                          final state = spot.y > 0.5 ? 'Odaklı' : 'Dağılmış';
                          return LineTooltipItem(
                            '$sec sn\n$state',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Event kaydı yok.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olaylar', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._events.map((e) {
              final type = e['event_type'] as String? ?? '';
              final ts = e['timestamp'] as int? ?? 0;
              final dt = DateTime.fromMillisecondsSinceEpoch(ts);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text('${_formatTime(dt)} — $type'),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    final remSec = sec % 60;
    return '${min}dk ${remSec}sn';
  }
}

