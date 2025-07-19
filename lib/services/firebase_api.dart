import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/main.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, String>> _getAuthHeaders() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      await _sendTokenToServer(fcmToken);
    }
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);
    initPushNotifications();
  }

  Future<void> _sendTokenToServer(String token) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) return;
    final url = Uri.parse('${ApiConfig.baseUrl}/update_fcm_token.php');
    try {
      await http.post(
        url,
        headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'token': token}),
      );
    } catch (e) {
      debugPrint('Gagal mengirim token FCM: $e');
    }
  }

  // --- FUNGSI BARU: KHUSUS UNTUK NAVIGASI ---
  Future<void> navigateToTicketDetail(String ticketId) async {
    if (ticketId == '0') return;
    
    debugPrint('Navigasi ke tiket ID: $ticketId');
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) return;
      final url = Uri.parse('${ApiConfig.baseUrl}/get_ticket_details.php?id=$ticketId');
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

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(
                ticket: ticket,
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

  // Fungsi ini sekarang HANYA untuk menyimpan dan memicu navigasi
  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Provider.of<NotificationProvider>(context, listen: false).addNotification(message);
    }
    
    final ticketId = message.data['ticket_id'];
    if (ticketId != null) {
      navigateToTicketDetail(ticketId);
    }
  }

  Future initPushNotifications() async {
    // Menangani notifikasi saat aplikasi TERBUKA (Foreground)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FIREBASE API] Notifikasi Foreground diterima: ${message.notification?.title}');
      
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Provider.of<NotificationProvider>(context, listen: false).addNotification(message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification?.title ?? 'Notifikasi Baru'),
            action: SnackBarAction(
              label: 'Lihat',
              onPressed: () => navigateToTicketDetail(message.data['ticket_id'] ?? '0'),
            ),
          ),
        );
      }
    });

    // Menangani notifikasi yang diketuk saat aplikasi TERTUTUP (Terminated)
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // Menangani notifikasi yang diketuk saat aplikasi di BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
  }
}