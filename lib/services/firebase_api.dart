// lib/services/firebase_api.dart

import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/main.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:anri/providers/app_data_provider.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- [PERBAIKAN 1: Definisikan channel notifikasi di sini] ---
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'Notifikasi Penting', // title
    description: 'Kanal ini digunakan untuk notifikasi penting.', // description
    importance: Importance.max,
  );

  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    // Tambahkan pengecekan null untuk notifikasi
    if (notification == null || notification.android == null) return;

    // Gunakan instance plugin yang sudah menjadi bagian dari kelas
    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@drawable/ic_notification',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: json.encode(message.data),
    );
  }

  Future<void> navigateToTicketDetail(String ticketId) async {
    final context = navigatorKey.currentContext;
    if (ticketId == '0' || context == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // Simpan referensi ke Navigator sebelum async gap
      final navigator = Navigator.of(context);
      // --- [PERBAIKAN 2: Hapus variabel scaffoldMessenger yang tidak terpakai] ---

      final results = await Future.wait([
        appDataProvider.fetchTeamMembers(),
        _getAuthHeaders(),
        SharedPreferences.getInstance(),
      ]);

      final headers = results[1] as Map<String, String>;
      if (headers.isEmpty) {
        if (navigator.canPop()) {
           navigator.pop();
        }
        return;
      }
      final prefs = results[2] as SharedPreferences;
      final currentUserName = prefs.getString('user_name') ?? 'Unknown';
      final url =
          Uri.parse('${ApiConfig.baseUrl}/get_ticket_details.php?id=$ticketId');
      final response = await http.get(url, headers: headers);
      
      if (navigator.canPop()) {
        navigator.pop(); // Tutup dialog loading
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['ticket_details'] != null) {
          final List<Attachment> attachments = (data['attachments'] as List)
              .map((attJson) => Attachment.fromJson(attJson))
              .toList();
          final ticket =
              Ticket.fromJson(data['ticket_details'], attachments: attachments);

          navigator.push(
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
              data['message'] ?? 'Gagal memuat detail tiket dari notifikasi.');
        }
      } else {
        throw Exception(
            'Gagal terhubung ke server (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (navigatorKey.currentContext != null &&
          navigatorKey.currentContext!.mounted) {
        if (Navigator.canPop(navigatorKey.currentContext!)) {
           Navigator.pop(navigatorKey.currentContext!);
        }
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      debugPrint('Gagal membuka detail tiket dari notifikasi: $e');
    }
  }

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Provider.of<NotificationProvider>(context, listen: false)
          .addNotification(message);
    }

    final ticketId = message.data['ticket_id'];
    if (ticketId != null) {
      navigateToTicketDetail(ticketId);
    }
  }

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $fcmToken');
    if (fcmToken != null) {
      await _sendTokenToServer(fcmToken);
    }
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);
    initPushNotifications();
    // Inisialisasi notifikasi lokal juga dipanggil di sini
    await initLocalNotifications();
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

  Future<void> initPushNotifications() async {
    // Buat kanal notifikasi sebelum listener diaktifkan
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    FirebaseMessaging.onMessage.listen((message) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .addNotification(message);
      }
      showLocalNotification(message);
    });
  }

  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const settings = InitializationSettings(android: android);

    await _flutterLocalNotificationsPlugin.initialize(
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