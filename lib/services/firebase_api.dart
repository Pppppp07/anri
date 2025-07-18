import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/main.dart'; // Impor untuk mengakses navigatorKey
import 'package:anri/models/ticket_model.dart'; // Impor model tiket
import 'package:anri/pages/ticket_detail_screen.dart'; // Impor halaman detail
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Fungsi helper untuk mendapatkan header otentikasi.
// Diletakkan di sini agar bisa diakses oleh fungsi di dalam kelas.
Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    return token != null ? {'Authorization': 'Bearer $token'} : {};
}

class FirebaseApi {
  // Buat instance dari Firebase Messaging untuk berinteraksi dengan FCM.
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Fungsi utama untuk menginisialisasi semua yang berhubungan dengan notifikasi.
  Future<void> initNotifications() async {
    // Minta izin dari pengguna untuk menampilkan notifikasi (wajib untuk iOS & Android 13+).
    await _firebaseMessaging.requestPermission();

    // Dapatkan FCM Token unik untuk perangkat ini.
    final fcmToken = await _firebaseMessaging.getToken();
    
    if (fcmToken == null) {
      debugPrint('[FIREBASE API] GAGAL mendapatkan FCM Token dari Firebase.');
      return;
    }
    debugPrint('[FIREBASE API] Berhasil mendapatkan FCM Token: $fcmToken');

    // Kirim token yang baru didapat ke server Anda.
    await _sendTokenToServer(fcmToken);

    // Siapkan listener jika Firebase memperbarui token perangkat ini di masa depan.
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);
    
    // Siapkan listener untuk menangani notifikasi yang masuk.
    initPushNotifications();
  }

  // Fungsi untuk mengirim token ke endpoint di server PHP Anda.
  Future<void> _sendTokenToServer(String token) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
        debugPrint('[FIREBASE API] Batal mengirim token, header otentikasi tidak ditemukan (user belum login).');
        return;
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/update_fcm_token.php');
    debugPrint('[FIREBASE API] Mencoba mengirim token ke server di URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({'token': token}),
      );

      debugPrint('[FIREBASE API] Respons dari server diterima. Kode Status: ${response.statusCode}');
      debugPrint('[FIREBASE API] Isi Respons: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('[FIREBASE API] Token berhasil diproses oleh server.');
      } else {
        debugPrint('[FIREBASE API] Server merespons dengan error.');
      }
    } catch (e) {
      debugPrint('[FIREBASE API] Terjadi error saat mengirim request: $e');
    }
  }
  
  // Fungsi untuk menangani notifikasi yang diketuk oleh pengguna.
  void handleMessage(RemoteMessage? message) async {
    // Jika tidak ada pesan, hentikan fungsi.
    if (message == null) return;

    // Ambil 'ticket_id' dari data payload notifikasi.
    final ticketId = message.data['ticket_id'];
    if (ticketId != null) {
      debugPrint('Notifikasi diketuk untuk tiket ID: $ticketId. Mengambil detail...');
      
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/get_ticket_details.php?id=$ticketId');
      
      try {
        final response = await http.get(url, headers: headers);
        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true && data['ticket_details'] != null) {
                final prefs = await SharedPreferences.getInstance();
                final currentUserName = prefs.getString('user_name') ?? 'Unknown';

                final List<Attachment> attachments = (data['attachments'] as List)
                    .map((attJson) => Attachment.fromJson(attJson))
                    .toList();
                final ticket = Ticket.fromJson(data['ticket_details'], attachments: attachments);

                // Gunakan GlobalKey untuk melakukan navigasi dari luar widget.
                navigatorKey.currentState?.push(
                    MaterialPageRoute(
                        builder: (context) => TicketDetailScreen(
                            ticket: ticket,
                            // Nilai ini bisa diambil dari provider jika perlu,
                            // namun untuk navigasi langsung, list kosong sudah cukup.
                            allCategories: const [], 
                            allTeamMembers: const [],
                            
                            currentUserName: currentUserName,
                        ),
                    ),
                );
            }
        }
      } catch (e) {
        debugPrint('Gagal membuka detail tiket dari notifikasi: $e');
      }
    }
  }

  // Fungsi untuk mendaftarkan semua listener notifikasi.
  Future initPushNotifications() async {
    // Listener untuk notifikasi yang menyebabkan aplikasi dibuka dari kondisi terminated (tertutup).
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // Listener untuk notifikasi yang diketuk saat aplikasi berjalan di background.
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
  }
}