import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Oturum bitiminde gösterilen detaylı sonuç ekranı
class SessionResultScreen extends StatelessWidget {
  final String mode;
  final int durationMs;
  final int focusedMs;
  final int distractCount;
  final List<Map<String, dynamic>> focusTimeline;

  const SessionResultScreen({
    super.key,
    required this.mode,
    required this.durationMs,
    required this.focusedMs,
    required this.distractCount,
    required this.focusTimeline,
  });

  @override
  Widget build(BuildContext context) {
    final focusRatio = durationMs > 0 ? (focusedMs / durationMs) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma Tamamlandı')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(focusRatio),
            const SizedBox(height: 16),
            _buildTimelineChart(context),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Ana Ekrana Dön'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double focusRatio) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Çalışma Özeti',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Mod', _modeName(mode)),
            _buildSummaryRow('Toplam Süre', _formatDuration(durationMs)),
            _buildSummaryRow('Odaklanma Süresi', _formatDuration(focusedMs)),
            _buildSummaryRow(
              'Odak Oranı',
              '${(focusRatio * 100).toStringAsFixed(1)}%',
            ),
            _buildSummaryRow('Dikkat Dağılma', '$distractCount kez'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildTimelineChart(BuildContext context) {
    if (focusTimeline.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Zaman çizelgesi verisi mevcut değil.'),
        ),
      );
    }

    // Timeline verisini LineChart için dönüştür
    final spots = <FlSpot>[];
    final startTime = focusTimeline.first['timestamp'] as int;

    for (final point in focusTimeline) {
      final timestamp = point['timestamp'] as int;
      final focused = point['focused'] as bool;
      final elapsedSec = (timestamp - startTime) / 1000.0;
      spots.add(FlSpot(elapsedSec, focused ? 1.0 : 0.0));
    }

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
                        interval: (durationMs / 1000 / 5).ceilToDouble().clamp(
                          10,
                          60,
                        ),
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
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
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

  String _modeName(String mode) {
    switch (mode) {
      case 'book':
        return 'Sadece Kitap';
      case 'phone':
        return 'Sadece Telefon';
      case 'hybrid':
        return 'Hibrit';
      default:
        return mode;
    }
  }

  String _formatDuration(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    final remSec = sec % 60;
    return '${min}dk ${remSec}sn';
  }
}
