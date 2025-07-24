import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationModel {
  final String? messageId;
  final String title;
  final String body;
  final String ticketId;
  final DateTime receivedAt;
  bool isRead; // <-- 1. TAMBAHKAN PROPERTI INI

  NotificationModel({
    this.messageId,
    required this.title,
    required this.body,
    required this.ticketId,
    required this.receivedAt,
    this.isRead = false, // <-- 2. TAMBAHKAN DI KONSTRUKTOR
  });

  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    return NotificationModel(
      messageId: message.messageId,
      title: message.data['title'] ?? 'Tanpa Judul',
      body: message.data['body'] ?? 'Tanpa Isi',
      ticketId: message.data['ticket_id'] ?? '0',
      receivedAt: DateTime.now(),
      // isRead akan otomatis 'false' saat dibuat
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      messageId: json['messageId'],
      title: json['title'],
      body: json['body'],
      ticketId: json['ticketId'],
      receivedAt: DateTime.parse(json['receivedAt']),
      isRead: json['isRead'] ?? false, // <-- 3. BACA DARI JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'title': title,
      'body': body,
      'ticketId': ticketId,
      'receivedAt': receivedAt.toIso8601String(),
      'isRead': isRead, // <-- 4. SIMPAN KE JSON
    };
  }
}