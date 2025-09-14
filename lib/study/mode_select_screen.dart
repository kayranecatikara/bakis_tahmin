import 'package:flutter/material.dart';
import 'study_screen.dart';

/// Çalışma modu seçenekleri
enum StudyMode { book, phone, hybrid }

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  void _openStudy(BuildContext context, StudyMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mod Seçimi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _ModeCard(
              icon: Icons.menu_book,
              title: 'Sadece Kitap',
              description:
                  'Telefon sabit, kitap odaklı. Başını kitaptan kaldırırsan uyarı.',
              onTap: () => _openStudy(context, StudyMode.book),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: Icons.smartphone,
              title: 'Sadece Telefon',
              description: 'Ekran odaklı. Ekran dışına bakarsan uyarı.',
              onTap: () => _openStudy(context, StudyMode.phone),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: Icons.merge_type,
              title: 'Hibrit',
              description:
                  'Hem kitap hem ekran kabul. İkisi dışına bakarsan uyarı.',
              onTap: () => _openStudy(context, StudyMode.hybrid),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
