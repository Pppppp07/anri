// lib/main.dart

import 'package:anri/models/notification_model.dart';
import 'package:anri/pages/splash_screen.dart';
import 'package:anri/providers/app_data_provider.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:anri/providers/settings_provider.dart';
import 'package:anri/providers/theme_provider.dart';
import 'package:anri/providers/ticket_provider.dart';
import 'package:anri/services/firebase_api.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final navigatorKey = GlobalKey<NavigatorState>();

// Handler ini harus berada di luar kelas (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inisialisasi Firebase agar plugin bisa digunakan di background isolate.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notifikasi Background Diterima: ${message.messageId}");

  if (message.notification == null) {
    debugPrint("[Background Handler] Pesan ini adalah data-only, membuat notifikasi lokal.");

    // Logika untuk menyimpan notifikasi (opsional, bisa dipertahankan jika diperlukan)
    final prefs = await SharedPreferences.getInstance();
    final List<String> notificationsJson =
        prefs.getStringList('notification_history') ?? [];
    final List<NotificationModel> notifications = notificationsJson
        .map((jsonString) =>
            NotificationModel.fromJson(json.decode(jsonString)))
        .toList();
    final newNotification = NotificationModel.fromRemoteMessage(message);

    if (newNotification.messageId == null ||
        !notifications.any((n) => n.messageId == newNotification.messageId)) {
      notifications.insert(0, newNotification);
      if (notifications.length > 50) {
        notifications.removeLast();
      }
      final List<String> updatedNotificationsJson =
          notifications.map((notif) => json.encode(notif.toJson())).toList();
      await prefs.setStringList(
          'notification_history', updatedNotificationsJson);
    }
    
    // Panggil metode terpusat untuk menampilkan notifikasi lokal.
    // Hanya panggil ini jika message.notification-nya null.
    await FirebaseApi().showLocalNotification(message);
  } else {
    debugPrint("[Background Handler] Pesan ini memiliki payload notifikasi, sistem akan menampilkannya.");
  }
  // --- [AKHIR PERBAIKAN UTAMA] ---
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Gunakan firebase_options.dart untuk inisialisasi
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await initializeDateFormatting('id_ID', null);
  await dotenv.load(fileName: ".env");

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint(details.toString());
    // Widget error fallback Anda
    return Material(
      child: Center(
        child: Text(
          'Terjadi error pada aplikasi.',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AppDataProvider()),
        Provider<FirebaseApi>(create: (_) => FirebaseApi()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Helpdesk Mobile',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
          surface: Colors.white,
          background: const Color(0xFFF0F4F8),
          surfaceContainerHighest: const Color(0xFFE3E3E3),
          onPrimaryContainer: Colors.black,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.lightBlue.shade300,
          surface: const Color.fromARGB(255, 25, 34, 44),
          background: const Color(0xFF1C2833),
          surfaceContainerLowest: const Color(0xFF1C2833),
          surfaceContainerHighest: const Color.fromARGB(255, 29, 40, 52),
          onPrimaryContainer: Colors.white,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color.fromARGB(255, 29, 40, 52),
          selectedItemColor: Colors.lightBlue.shade200,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}