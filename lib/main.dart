import 'package:flutter/material.dart';
import 'home/home_screen.dart';

void main() {
  runApp(const FocusGuardStudyApp());
}

class FocusGuardStudyApp extends StatelessWidget {
  const FocusGuardStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusGuard Study',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
