// lib/services/firebase_api.dart

import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/main.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:anri/providers/app_data_provider.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
  final _localNotifications = FlutterLocalNotificationsPlugin();

  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  // Fungsi terpusat untuk menampilkan notifikasi
  Future<void> showLocalNotification(RemoteMessage message) async {
    await initLocalNotifications();

    final String title = message.data['title'] ?? 'Notifikasi Baru';
    final String body = message.data['body'] ?? 'Anda memiliki pesan baru.';
    final String? ticketId = message.data['ticket_id'];

    // --- [PERBAIKAN UTAMA DI SINI] ---
    // ID unik dibuat dari `millisecondsSinceEpoch` namun dibatasi agar sesuai dengan integer 32-bit.
    final int notificationId = DateTime.now().millisecondsSinceEpoch.toSigned(
      31,
    );

    _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@drawable/ic_notification',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: ticketId,
    );
  }

  // Method navigateToTicketDetail tetap sama
  Future<void> navigateToTicketDetail(String ticketId) async {
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

  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const settings = InitializationSettings(android: android);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload != '0') {
          navigateToTicketDetail(payload);
        }
      },
    );

    final platform = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await platform?.createNotificationChannel(_androidChannel);
  }

  Future<void> initPushNotifications() async {
    await initLocalNotifications();

    // Foreground handler
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FIREBASE API] Foreground notification received.');

      // --- AWAL PERBAIKAN ---
      // Tambahkan notifikasi ke provider agar masuk ke riwayat di halaman notifikasi
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).addNotification(message);
      }
      // --- AKHIR PERBAIKAN ---

      // Tampilkan notifikasi lokal seperti biasa
      showLocalNotification(message);
    });

    // Handler saat notifikasi di-tap (dari background)
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

    // Handler saat notifikasi di-tap (dari terminated)
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
  }
}
