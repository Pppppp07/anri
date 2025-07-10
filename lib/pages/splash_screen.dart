import 'package:anri/home_page.dart';
import 'package:anri/pages/login_page.dart';
import 'package:anri/providers/settings_provider.dart';
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

    // Memanggil fungsi utama setelah frame pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  // Fungsi utama yang menangani alur pembukaan aplikasi
  Future<void> _checkLoginStatus() async {
    // Beri jeda agar splash screen terlihat
    await Future.delayed(const Duration(milliseconds: 2500));
    
    // Pastikan widget masih ada sebelum menggunakan context
    if (!mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    
    // --- PERBAIKAN UTAMA ADA DI SINI ---
    // Baris ini 'memaksa' aplikasi untuk menunggu sampai semua pengaturan
    // (termasuk status kunci aplikasi) selesai dimuat dari memori.
    await settingsProvider.loadSettings();
    // ------------------------------------

    // Setelah 'await' di atas, nilai ini dijamin yang paling update.
    final bool appLockEnabled = settingsProvider.isAppLockEnabled;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;

    // Jika pengguna sudah login sebelumnya
    if (isLoggedIn) {
      // DAN kunci aplikasi aktif, maka minta otentikasi
      if (appLockEnabled) {
        bool authenticated = await _authenticateWithExit();
        // Jika otentikasi berhasil, baru masuk ke halaman utama
        if (authenticated) {
          _navigateToHome(prefs);
        }
      } else {
        // Jika tidak ada kunci aplikasi, langsung masuk ke halaman utama
        _navigateToHome(prefs);
      }
    } else {
      // Jika belum login, selalu ke halaman login
      _navigateToLogin();
    }
  }

  // Fungsi untuk otentikasi, akan menutup aplikasi jika gagal atau dibatalkan
  Future<bool> _authenticateWithExit() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) {
        // Jika perangkat tidak mendukung, anggap saja berhasil agar tidak terkunci selamanya
        return true;
      }

      return await auth.authenticate(
        localizedReason: 'Silakan otentikasi untuk membuka aplikasi ANRI Helpdesk',
        options: const AuthenticationOptions(
          stickyAuth: true, // Dialog tidak hilang jika aplikasi ke background
          biometricOnly: false, // Izinkan PIN/Pola jika biometrik gagal
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Error otentikasi: $e");
      // Jika pengguna membatalkan atau terjadi error, tutup aplikasi
      SystemNavigator.pop();
      return false;
    }
  }

  // Helper untuk navigasi ke halaman utama
  void _navigateToHome(SharedPreferences prefs) {
    final String? userName = prefs.getString('user_name');
    final String? authToken = prefs.getString('auth_token');

    if (userName != null && authToken != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            currentUserName: userName,
            authToken: authToken,
          ),
        ),
      );
    } else {
      _navigateToLogin();
    }
  }

  // Helper untuk navigasi ke halaman login
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