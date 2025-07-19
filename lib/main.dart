import 'dart:convert';
import 'package:anri/models/notification_model.dart';
import 'package:anri/pages/splash_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

// Kunci global untuk state navigator, memungkinkan navigasi dari luar widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

// Handler ini harus berada di luar kelas (top-level function) agar bisa berjalan
// saat aplikasi berada di background atau terminate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase diinisialisasi sebelum digunakan.
  await Firebase.initializeApp();
  debugPrint("Notifikasi Background Diterima: ${message.messageId}");

  // --- AWAL LOGIKA PENYIMPANAN DI BACKGROUND ---
  try {
    final newNotification = NotificationModel.fromRemoteMessage(message);
    final prefs = await SharedPreferences.getInstance();
    
    // Ambil daftar notifikasi yang sudah ada
    const historyKey = 'notification_history';
    final List<String> notificationsJson = prefs.getStringList(historyKey) ?? [];
    
    // Tambahkan yang baru di awal
    notificationsJson.insert(0, json.encode(newNotification.toJson()));

    // Batasi jumlah riwayat agar tidak terlalu besar
    if (notificationsJson.length > 50) {
      notificationsJson.removeLast();
    }
    
    // Simpan kembali ke SharedPreferences
    await prefs.setStringList(historyKey, notificationsJson);
    
    // Tambah hitungan notifikasi belum dibaca
    const unreadCountKey = 'notification_unread_count';
    int unreadCount = prefs.getInt(unreadCountKey) ?? 0;
    unreadCount++;
    await prefs.setInt(unreadCountKey, unreadCount);

    debugPrint("Notifikasi background BERHASIL DISIMPAN ke SharedPreferences.");
  } catch (e) {
    debugPrint("Gagal menyimpan notifikasi background: $e");
  }
  // --- AKHIR LOGIKA PENYIMPANAN DI BACKGROUND ---
}

Future<void> main() async {
  // Pastikan semua binding Flutter siap sebelum menjalankan kode.
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase sebagai langkah pertama.
  await Firebase.initializeApp();
  
  // Daftarkan handler untuk pesan notifikasi background.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inisialisasi format tanggal untuk bahasa Indonesia.
  await initializeDateFormatting('id_ID', null);
  // Muat variabel lingkungan dari file .env.
  await dotenv.load(fileName: ".env");

  // Error handler kustom untuk menggantikan Red Screen of Death.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint(details.toString());
    return Material(
      child: Container(
        color: const Color(0xFF212f3c),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'Oops, Terjadi Masalah',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Silakan coba restart aplikasi. Jika masalah berlanjut, hubungi developer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
  
  // Jalankan aplikasi dengan semua provider yang dibutuhkan.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // Sediakan FirebaseApi service ke widget tree.
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
      // Pasang navigatorKey di sini.
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
          surfaceVariant: Colors.blue.shade50,
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}