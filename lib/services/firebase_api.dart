// lib/services/firebase_api.dart

import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/main.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:anri/providers/app_data_provider.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:anri/providers/ticket_provider.dart';
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

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifikasi Penting',
    description: 'Kanal ini digunakan untuk notifikasi penting.',
    importance: Importance.max,
  );

  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || notification.android == null) return;

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

  // --- [LOGIKA INI TETAP DIJADIKAN JARING PENGAMAN] ---
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
      final navigator = Navigator.of(context);

      // 1. Ambil detail tiket terlebih dahulu untuk mengetahui nama kategorinya.
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) {
        if (navigator.canPop()) navigator.pop();
        return;
      }
      final url =
          Uri.parse('${ApiConfig.baseUrl}/get_ticket_details.php?id=$ticketId');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat detail tiket (Status: ${response.statusCode})');
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['ticket_details'] == null) {
        throw Exception(data['message'] ?? 'Gagal memuat data tiket dari server.');
      }
      
      final ticketJson = data['ticket_details'];
      final String newCategoryName = ticketJson['category_name'] as String;

      // 2. Cek apakah kategori dari tiket ini sudah ada di provider.
      final currentCategories = appDataProvider.categoryListForDropdown;
      if (!currentCategories.contains(newCategoryName)) {
        // Jika TIDAK ADA, paksa refresh dan tunggu sampai selesai.
        debugPrint("Kategori '$newCategoryName' tidak ditemukan, memulai refresh paksa...");
        await appDataProvider.fetchCategories(forceRefresh: true);
      }
      
      // Sinkronkan juga anggota tim untuk konsistensi.
      await appDataProvider.fetchTeamMembers(forceRefresh: true);
      
      // Tutup dialog loading.
      if (navigator.canPop()) {
        navigator.pop();
      }

      // 3. Sekarang data dijamin sinkron, buat objek tiket dan navigasi.
      final List<Attachment> attachments = (data['attachments'] as List)
          .map((attJson) => Attachment.fromJson(attJson))
          .toList();
      final ticket =
          Ticket.fromJson(ticketJson, attachments: attachments);

      final prefs = await SharedPreferences.getInstance();
      final currentUserName = prefs.getString('user_name') ?? 'Unknown';

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

    } catch (e) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      debugPrint('Gagal membuka detail tiket: $e');
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
    if (fcmToken != null) {
      await _sendTokenToServer(fcmToken);
    }
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);
    initPushNotifications();
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
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    FirebaseMessaging.onMessage.listen((message) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // --- [PERBAIKAN UTAMA DI SINI] ---
        // Lakukan refresh untuk semua data yang mungkin usang secara proaktif.
        // Ini untuk memastikan state aplikasi konsisten sebelum user berinteraksi.
        final ticketProvider = Provider.of<TicketProvider>(context, listen: false);
        final appDataProvider = Provider.of<AppDataProvider>(context, listen: false);
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

        // Jalankan semua pembaruan secara bersamaan untuk efisiensi.
        Future.wait([
          ticketProvider.fetchTickets(status: 'All', category: 'All', searchQuery: '', priority: 'All', assignee: ''),
          appDataProvider.fetchCategories(forceRefresh: true),
          appDataProvider.fetchTeamMembers(forceRefresh: true),
        ]);

        notificationProvider.addNotification(message);
        // --- [AKHIR PERBAIKAN] ---
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