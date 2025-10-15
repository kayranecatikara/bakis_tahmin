import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../logs/session_logger.dart';
import 'session_detail_screen.dart';

/// Oturum özeti modeli
class SessionSummary {
  final String fileName;
  final DateTime sessionStart;
  final int durationMs;
  final double focusRatio;
  final int distractCount;
  final String mode;

  SessionSummary({
    required this.fileName,
    required this.sessionStart,
    required this.durationMs,
    required this.focusRatio,
    required this.distractCount,
    required this.mode,
  });
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SessionLogger _logger = SessionLogger();
  List<SessionSummary> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final files = await _logger.listLogFiles();
    final summaries = <SessionSummary>[];

    for (final f in files) {
      if (f is! File) continue;
      try {
        final lines = await (f as File).readAsLines();
        DateTime? start;
        int? duration;
        double? focusRatio;
        int? distractCount;
        String? mode;

        for (final line in lines) {
          final json = jsonDecode(line) as Map<String, dynamic>;
          if (json['type'] == 'session_start') {
            start = DateTime.parse(json['timestamp'] as String);
          } else if (json['type'] == 'event' && json['event_type'] == 'session_start') {
            mode = json['data']?['mode'] as String?;
          } else if (json['type'] == 'event' && json['event_type'] == 'session_end') {
            final data = json['data'] as Map<String, dynamic>?;
            duration = data?['durationMs'] as int?;
            focusRatio = (data?['focusRatio'] as num?)?.toDouble();
            distractCount = data?['distractCount'] as int?;
            mode ??= data?['mode'] as String?;
          }
        }

        if (start != null && duration != null) {
          summaries.add(SessionSummary(
            fileName: f.path.split('/').last,
            sessionStart: start,
            durationMs: duration,
            focusRatio: focusRatio ?? 0.0,
            distractCount: distractCount ?? 0,
            mode: mode ?? 'unknown',
          ));
        }
      } catch (e) {
        // skip malformed files
      }
    }

    summaries.sort((a, b) => b.sessionStart.compareTo(a.sessionStart));
    setState(() {
      _sessions = summaries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raporlarım')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('Henüz oturum kaydı yok.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(_modeIcon(s.mode)),
                        title: Text('${s.mode} — ${_formatDate(s.sessionStart)}'),
                        subtitle: Text(
                          'Süre: ${_formatDuration(s.durationMs)} • Odak: ${(s.focusRatio * 100).toStringAsFixed(1)}% • Uyarı: ${s.distractCount}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(
                                fileName: s.fileName,
                                summary: s,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'book':
        return Icons.menu_book;
      case 'phone':
        return Icons.smartphone;
      case 'hybrid':
        return Icons.merge_type;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    final remSec = sec % 60;
    return '${min}dk ${remSec}sn';
  }
}

