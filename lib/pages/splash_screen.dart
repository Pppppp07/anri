// lib/pages/splash_screen.dart

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
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Memanggil alur utama setelah frame pertama selesai di-render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  // --- [PERBAIKAN UTAMA] Alur inisialisasi aplikasi terpusat ---
  Future<void> _initializeApp() async {
    // Beri jeda agar splash screen terlihat.
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (!mounted) return;

    // 1. Muat semua data esensial dari provider.
    // `context.read` aman digunakan di sini karena ini adalah event satu kali.
    final settingsProvider = context.read<SettingsProvider>();
    final appDataProvider = context.read<AppDataProvider>();

    // Menunggu semua data siap: pengaturan dan data anggota tim.
    await Future.wait([
      settingsProvider.loadSettings(),
      appDataProvider.fetchTeamMembers(),
    ]);

    if (!mounted) return;

    // 2. Cek status login.
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    // 3. Cek apakah aplikasi dibuka dari notifikasi saat terminated.
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (!mounted) return;

    // 4. Tentukan alur navigasi berdasarkan status login dan notifikasi.
    if (isLoggedIn) {
      final bool appLockEnabled = settingsProvider.isAppLockEnabled;
      bool authenticated = true; // Anggap berhasil jika kunci aplikasi mati.

      if (appLockEnabled) {
        authenticated = await _authenticateWithExit();
      }

      if (authenticated) {
        // Jika notifikasi awal ada, langsung navigasi ke detail tiket.
        if (initialMessage != null) {
          _navigateToHomeAndHandleNotification(prefs, initialMessage);
        } else {
          _navigateToHome(prefs);
        }
      }
    } else {
      // Jika belum login, selalu ke halaman login.
      _navigateToLogin();
    }
  }

  Future<bool> _authenticateWithExit() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) return true;

      return await auth.authenticate(
        localizedReason: 'Silakan otentikasi untuk membuka aplikasi ANRI Helpdesk',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } on PlatformException catch (e) {
      debugPrint("Error otentikasi: $e");
      SystemNavigator.pop();
      return false;
    }
  }

  void _navigateToHome(SharedPreferences prefs) {
    final String? userName = prefs.getString('user_name');
    final String? authToken = prefs.getString('auth_token');

    if (userName != null && authToken != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(currentUserName: userName, authToken: authToken),
        ),
      );
    } else {
      _navigateToLogin();
    }
  }

  // --- [FUNGSI BARU] Navigasi ke HomePage lalu langsung proses notifikasi ---
  void _navigateToHomeAndHandleNotification(SharedPreferences prefs, RemoteMessage message) {
    final String? userName = prefs.getString('user_name');
    final String? authToken = prefs.getString('auth_token');

    if (userName != null && authToken != null && mounted) {
      // Ganti halaman saat ini dengan HomePage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(currentUserName: userName, authToken: authToken),
        ),
      );
      
      // Setelah HomePage siap, panggil logika navigasi notifikasi.
      // Memberi sedikit jeda memastikan HomePage sudah terbangun sepenuhnya.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
           final ticketId = message.data['ticket_id'];
           if (ticketId != null) {
              // Gunakan context dari provider, bukan dari splash screen yang akan hilang.
              context.read<FirebaseApi>().navigateToTicketDetail(ticketId);
           }
        }
      });

    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF2c3e50), const Color(0xFF212f3c)]
                : [Colors.white, const Color(0xFFE0F2F7), const Color(0xFFBBDEFB), Colors.blueAccent],
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