// lib/main.dart

import 'package:anri/home_page.dart';
import 'package:anri/models/notification_model.dart';
import 'package:anri/pages/login_page.dart';
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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firebase_options.dart';

// --- Variabel global dan handler background tetap di sini ---
final navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notifikasi Penting',
  description: 'Kanal ini digunakan untuk notifikasi penting.',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notifikasi Background Diterima: ${message.messageId}");
  final prefs = await SharedPreferences.getInstance();

  final List<String> notificationsJson =
      prefs.getStringList('notification_history') ?? [];
  final List<NotificationModel> notifications = notificationsJson
      .map((jsonString) => NotificationModel.fromJson(json.decode(jsonString)))
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
    await prefs.setStringList('notification_history', updatedNotificationsJson);

    final int unreadCount =
        (prefs.getInt('notification_unread_count') ?? 0) + 1;
    await prefs.setInt('notification_unread_count', unreadCount);
    debugPrint(
      '[Background Handler] Notifikasi disimpan, total belum dibaca: $unreadCount',
    );
  } else {
    debugPrint(
      '[Background Handler] Notifikasi duplikat terdeteksi, tidak disimpan.',
    );
  }
}

Future<void> main() async {
  // 1. Pastikan semua binding siap sebelum menjalankan kode async.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Lakukan semua inisialisasi yang membutuhkan 'await' DI SINI, SEBELUM runApp().
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);

  // Buat kanal notifikasi
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Set handler notifikasi background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Cek status login dari SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? userName = prefs.getString('user_name');
  final String? authToken = prefs.getString('auth_token');

  // 4. Tentukan halaman tujuan (nextPage) berdasarkan status login
  Widget nextPage;
  if (isLoggedIn && userName != null && authToken != null) {
    // Jika sudah login, siapkan HomePage
    nextPage = HomePage(currentUserName: userName, authToken: authToken);
  } else {
    // Jika belum, siapkan LoginPage
    nextPage = const LoginPage();
  }

  // Konfigurasi ErrorWidget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint(details.toString());
    return const Material(
      child: Center(
        child: Text(
          'Terjadi error pada aplikasi.',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  };

  // 5. Jalankan aplikasi dengan halaman awal berupa SplashScreen,
  //    yang kemudian akan mengarahkan ke nextPage.
  runApp(
    MyApp(
      initialPage: SplashScreen(
        nextPage: nextPage,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialPage;

  // Terima parameter halaman awal
  const MyApp({super.key, required this.initialPage});

  @override
  Widget build(BuildContext context) {
    // Konfigurasi MultiProvider tidak perlu diubah
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AppDataProvider()),
        Provider<FirebaseApi>(create: (_) => FirebaseApi()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Konfigurasi MaterialApp Anda tetap sama
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
                surfaceContainerHighest:
                    const Color.fromARGB(255, 29, 40, 52),
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
            // Gunakan `initialPage` (yaitu SplashScreen) sebagai halaman pertama
            home: initialPage,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}