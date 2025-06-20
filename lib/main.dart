import 'package:flutter/material.dart';
import 'package:anri/pages/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart'; // 1. Tambahkan import ini

// 2. Ubah fungsi main menjadi async
Future<void> main() async {
  // 3. Pastikan semua widget Flutter sudah siap sebelum menjalankan proses lain
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Inisialisasi (muat) data format tanggal untuk Bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}

// Widget utama aplikasi (tidak ada perubahan di sini)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpdesk Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false, // Menghilangkan banner debug
    );
  }
}
