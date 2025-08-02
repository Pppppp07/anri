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
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Controller untuk animasi Text-Reveal
  late AnimationController _textAnimationController;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Animasi akan bernilai dari -1.0 hingga 2.0 untuk loop yang mulus
    _textAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.linear),
    );

    // Memanggil alur utama aplikasi Anda
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  // --- [PERUBAHAN UTAMA DI SINI] ---
  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    
    final settingsProvider = context.read<SettingsProvider>();
    final appDataProvider = context.read<AppDataProvider>();
    
    // Sekarang memanggil fetchCategories() bersamaan dengan fetchTeamMembers()
    await Future.wait([
      settingsProvider.loadSettings(),
      appDataProvider.fetchTeamMembers(),
      appDataProvider.fetchCategories(), // <-- FUNGSI BARU DIPANGGIL DI SINI
    ]);

    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    
    if (!mounted) return;
    
    if (isLoggedIn) {
      final bool appLockEnabled = settingsProvider.isAppLockEnabled;
      bool authenticated = true;
      if (appLockEnabled) {
        authenticated = await _authenticateWithExit();
      }
      if (authenticated) {
        if (initialMessage != null) {
          _navigateToHomeAndHandleNotification(prefs, initialMessage);
        } else {
          _navigateToHome(prefs);
        }
      }
    } else {
      _navigateToLogin();
    }
  }
  // --- [AKHIR PERUBAHAN] ---

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

  void _navigateToHomeAndHandleNotification(SharedPreferences prefs, RemoteMessage message) {
    final String? userName = prefs.getString('user_name');
    final String? authToken = prefs.getString('auth_token');
    if (userName != null && authToken != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(currentUserName: userName, authToken: authToken),
        ),
      );
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
           final ticketId = message.data['ticket_id'];
           if (ticketId != null) {
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
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final backgroundDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: isDarkMode
            ? [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.background
              ]
            : [
                Colors.white,
                const Color(0xFFE0F2F7),
                const Color(0xFFBBDEFB),
                Colors.blueAccent
              ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: backgroundDecoration,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'anriLogo',
                child: Image.asset(
                  'assets/images/anri_logo.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      final slidePosition = _textAnimation.value;
                      const highlightWidth = 0.2;

                      return LinearGradient(
                        colors: const [
                          Colors.blue,
                          Colors.lightBlueAccent,
                          Colors.white,
                          Colors.lightBlueAccent,
                          Colors.blue,
                        ],
                        stops: [
                          slidePosition - (highlightWidth * 2),
                          slidePosition - highlightWidth,
                          slidePosition,
                          slidePosition + highlightWidth,
                          slidePosition + (highlightWidth * 2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds);
                    },
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Helpdesk',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}