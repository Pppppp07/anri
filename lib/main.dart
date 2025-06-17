import 'package:flutter/material.dart';
import 'package:anri/pages/splash_screen.dart';

// Fungsi utama yang menjalankan aplikasi Flutter
void main() {
  runApp(const MyApp());
}

// Widget utama aplikasi
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpdesk Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, primary: Colors.blue.shade700),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(), // Ini akan tetap berfungsi karena sudah di-import
    );
  }
}

// Tidak ada lagi kode SplashScreen atau LoginPage di sini.