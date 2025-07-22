import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationModel {
  // --- [PERUBAHAN 1] Tambahkan messageId ---
  final String? messageId;
  final String title;
  final String body;
  final String ticketId;
  final DateTime receivedAt;

  NotificationModel({
    this.messageId, // Tambahkan di constructor
    required this.title,
    required this.body,
    required this.ticketId,
    required this.receivedAt,
  });

  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    return NotificationModel(
      // --- [PERUBAHAN 2] Ambil messageId dari RemoteMessage ---
      messageId: message.messageId,
      title: message.notification?.title ?? 'Tanpa Judul',
      body: message.notification?.body ?? 'Tanpa Isi',
      ticketId: message.data['ticket_id'] ?? '0',
      receivedAt: DateTime.now(),
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      // --- [PERUBAHAN 3] Baca messageId dari JSON ---
      messageId: json['messageId'],
      title: json['title'],
      body: json['body'],
      ticketId: json['ticketId'],
      receivedAt: DateTime.parse(json['receivedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // --- [PERUBAHAN 4] Simpan messageId ke JSON ---
      'messageId': messageId,
      'title': title,
      'body': body,
      'ticketId': ticketId,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }
}