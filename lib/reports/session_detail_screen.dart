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
        for (final line in lines) {
          final json = jsonDecode(line) as Map<String, dynamic>;
          if (json['type'] == 'event') {
            events.add(json);
          }
        }
        setState(() {
          _events = events;
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
    // Basit odak yüzdesi göstergesi
    final focusPct = widget.summary.focusRatio * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Odak Grafiği', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.center,
                  maxY: 100,
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(toY: focusPct, color: Colors.green, width: 40),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(toY: 100 - focusPct, color: Colors.red, width: 40),
                    ]),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('Odak');
                          if (value == 1) return const Text('Dağılma');
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

