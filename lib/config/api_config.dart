// lib/config/api_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Ganti konstanta statis dengan getter statis
  static String get baseUrl {
    // Ambil nilai dari environment variable 'API_BASE_URL'
    // Tambahkan fallback untuk keamanan jika variabel tidak ditemukan
    return dotenv.env['API_BASE_URL'] ?? 'http://default.url.com';
  }
}