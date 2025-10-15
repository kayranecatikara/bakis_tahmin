import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Auth sonraya ertelendi. Şimdilik Home ekranı üzerinden devam ediyoruz.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
 