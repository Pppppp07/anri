// lib/services/firebase_api.dart

import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/main.dart'; // <-- [TAMBAHAN 1] Import main.dart untuk akses 'channel'
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:anri/providers/app_data_provider.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
// --- [TAMBAHAN 2] Import package notifikasi lokal ---
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fungsi helper _getAuthHeaders tetap sama
Future<Map<String, String>> _getAuthHeaders() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Method navigateToTicketDetail tetap sama
  Future<void> navigateToTicketDetail(String ticketId) async {
    // ... (Tidak ada perubahan di dalam fungsi ini, biarkan seperti semula)
    if (ticketId == '0' || navigatorKey.currentContext == null) return;
    final context = navigatorKey.currentContext!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final appDataProvider = Provider.of<AppDataProvider>(
        context,
        listen: false,
      );
      final results = await Future.wait([
        appDataProvider.fetchTeamMembers(),
        _getAuthHeaders(),
        SharedPreferences.getInstance(),
      ]);
      if (!context.mounted) {
        Navigator.pop(context);
        return;
      }
      final headers = results[1] as Map<String, String>;
      if (headers.isEmpty) {
        Navigator.pop(context);
        return;
      }
      final prefs = results[2] as SharedPreferences;
      final currentUserName = prefs.getString('user_name') ?? 'Unknown';
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/get_ticket_details.php?id=$ticketId',
      );
      final response = await http.get(url, headers: headers);
      Navigator.pop(context);
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['ticket_details'] != null) {
          final List<Attachment> attachments = (data['attachments'] as List)
              .map((attJson) => Attachment.fromJson(attJson))
              .toList();
          final ticket = Ticket.fromJson(
            data['ticket_details'],
            attachments: attachments,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(
                ticket: ticket,
                allCategories: appDataProvider.categoryListForDropdown,
                allTeamMembers: appDataProvider.teamMembers,
                currentUserName: currentUserName,
              ),
            ),
          );
        } else {
          throw Exception(
            data['message'] ?? 'Gagal memuat detail tiket dari notifikasi.',
          );
        }
      } else {
        throw Exception(
          'Gagal terhubung ke server (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint('Gagal membuka detail tiket dari notifikasi: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).addNotification(message);
    }

    final ticketId = message.data['ticket_id'];
    if (ticketId != null) {
      navigateToTicketDetail(ticketId);
    }
  }

  // --- [PERUBAHAN 1] Modifikasi initNotifications ---
  // Sekarang menerima instance plugin notifikasi lokal sebagai argumen.
  Future<void> initNotifications(
      FlutterLocalNotificationsPlugin localNotificationsPlugin) async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $fcmToken');
    if (fcmToken != null) {
      await _sendTokenToServer(fcmToken);
    }
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);

    // Kirim instance plugin ke handler notifikasi push
    initPushNotifications(localNotificationsPlugin);
  }

  Future<void> _sendTokenToServer(String token) async {
    // ... (Tidak ada perubahan di dalam fungsi ini)
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) return;
    final url = Uri.parse('${ApiConfig.baseUrl}/update_fcm_token.php');
    try {
      await http.post(
        url,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({'token': token}),
      );
    } catch (e) {
      debugPrint('Gagal mengirim token FCM: $e');
    }
  }

  // --- [PERUBAHAN 2] Modifikasi initPushNotifications ---
  Future<void> initPushNotifications(
      FlutterLocalNotificationsPlugin localNotificationsPlugin) async {
    // Handler untuk notifikasi yang di-tap (dari background)
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

    // Handler untuk notifikasi yang di-tap (dari terminated/ditutup)
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // --- [PERUBAHAN UTAMA] Listener untuk notifikasi yang masuk saat aplikasi di FOREGROUND ---
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      // Tambahkan notifikasi ke riwayat provider
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .addNotification(message);
      }

      // Tampilkan notifikasi mengambang menggunakan flutter_local_notifications
      localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id, // <-- Gunakan ID kanal dari main.dart
            channel.name,
            channelDescription: channel.description,
            icon: '@drawable/ic_notification', // Pastikan nama ikon ini benar
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        // Payload berisi ticket_id agar bisa di-handle saat di-tap
        payload: json.encode(message.data),
      );

      debugPrint(
        'Pesan diterima di foreground: ${notification.title}, ${notification.body}',
      );
    });
  }

  // Inisialisasi plugin notifikasi lokal (untuk onTap)
  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const settings = InitializationSettings(android: android);
    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          final data = json.decode(payload);
          final ticketId = data['ticket_id'];
          if (ticketId != null) {
            navigateToTicketDetail(ticketId);
          }
        }
      },
    );
  }
}