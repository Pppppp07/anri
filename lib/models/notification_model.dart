import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationModel {
  final String title;
  final String body;
  final String ticketId;
  final DateTime receivedAt;

  NotificationModel({
    required this.title,
    required this.body,
    required this.ticketId,
    required this.receivedAt,
  });

  // Konversi dari RemoteMessage (notifikasi Firebase) ke model kita
  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    return NotificationModel(
      title: message.notification?.title ?? 'Tanpa Judul',
      body: message.notification?.body ?? 'Tanpa Isi',
      ticketId: message.data['ticket_id'] ?? '0',
      receivedAt: DateTime.now(),
    );
  }

  // Konversi dari Map (saat dibaca dari SharedPreferences) ke model kita
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      title: json['title'],
      body: json['body'],
      ticketId: json['ticketId'],
      receivedAt: DateTime.parse(json['receivedAt']),
    );
  }

  // Konversi dari model kita ke Map (untuk disimpan ke SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'ticketId': ticketId,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }
}