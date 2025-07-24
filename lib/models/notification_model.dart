import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationModel {
  final String? messageId;
  final String title;
  final String body;
  final String ticketId;
  final DateTime receivedAt;

  NotificationModel({
    this.messageId,
    required this.title,
    required this.body,
    required this.ticketId,
    required this.receivedAt,
  });

  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    return NotificationModel(
      messageId: message.messageId,
      // --- PERBAIKAN DI SINI ---
      // Ambil judul dan isi dari message.data, bukan message.notification
      title: message.data['title'] ?? 'Tanpa Judul',
      body: message.data['body'] ?? 'Tanpa Isi',
      ticketId: message.data['ticket_id'] ?? '0',
      receivedAt: DateTime.now(),
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      messageId: json['messageId'],
      title: json['title'],
      body: json['body'],
      ticketId: json['ticketId'],
      receivedAt: DateTime.parse(json['receivedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'title': title,
      'body': body,
      'ticketId': ticketId,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }
}
