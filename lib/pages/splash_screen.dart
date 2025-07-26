// lib/pages/splash_screen.dart

import 'package:anri/main.dart'; 
import 'package:anri/home_page.dart';
import 'package:anri/pages/login_page.dart';
import 'package:anri/providers/app_data_provider.dart';
import 'package:anri/providers/settings_provider.dart';
import 'package:anri/services/firebase_api.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  // --- [PERUBAHAN 1] Tambahkan parameter `nextPage` ---
  // Halaman ini akan menerima halaman tujuan (HomePage atau LoginPage) dari main.dart
  final Widget nextPage;

  const SplashScreen({super.key, required this.nextPage});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // --- [PERUBAHAN 2] Hapus semua logika kompleks ---
    // Inisialisasi notifikasi yang berhubungan dengan UI (saat di-tap)
    // aman untuk dipanggil di sini.
    context.read<FirebaseApi>().initLocalNotifications();

    // Cukup atur timer untuk navigasi setelah 3 detik.
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.nextPage),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- [PERUBAHAN 3] Hapus semua fungsi yang tidak perlu ---
  // _initializeApp(), _authenticateWithExit(), _navigateToHome(),
  // _navigateToHomeAndHandleNotification(), dan _navigateToLogin()
  // semuanya sudah dihapus karena logikanya telah pindah ke main.dart.

  @override
  Widget build(BuildContext context) {
    // Tampilan UI (build method) Anda tidak perlu diubah,
    // karena sudah bagus dan hanya fokus menampilkan animasi.
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF2c3e50), const Color(0xFF212f3c)]
                : [
                    Colors.white,
                    const Color(0xFFE0F2F7),
                    const Color(0xFFBBDEFB),
                    Colors.blueAccent
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'anriLogo',
                    child: Image.asset(
                      'assets/images/anri_logo.png',
                      width: 250,
                      height: 250,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (bounds) {
                      final double value = _controller.value;
                      final Alignment begin = Alignment(
                        math.sin(value * 2 * math.pi * 2.0),
                        math.cos(value * 2 * math.pi * 1.5),
                      );
                      final Alignment end = Alignment(
                        math.cos(value * 2 * math.pi * 1.2),
                        math.sin(value * 2 * math.pi * 2.5),
                      );
                      return LinearGradient(
                        colors: [
                          Colors.blue.shade300,
                          Colors.blue.shade700,
                          Colors.lightBlueAccent,
                        ],
                        begin: begin,
                        end: end,
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'Helpdesk',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}