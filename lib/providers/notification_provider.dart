import 'dart:convert';
import 'package:anri/models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  final String _historyKey = 'notification_history';
  final String _unreadCountKey = 'notification_unread_count';

  final List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  NotificationProvider() {
    debugPrint('[Provider] NotificationProvider Dibuat.');
    loadNotifications();
  }

  // --- PERBAIKAN UTAMA ADA DI FUNGSI INI ---
  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    // PERINTAH KRUSIAL: Paksa untuk membaca ulang data terbaru dari disk
    await prefs.reload(); 
    
    final List<String> notificationsJson = prefs.getStringList(_historyKey) ?? [];
    _notifications.clear();
    _notifications.addAll(notificationsJson
        .map((jsonString) => NotificationModel.fromJson(json.decode(jsonString)))
        .toList());
        
    // Pindahkan pemuatan unread count ke sini agar data selalu sinkron
    _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;
    debugPrint('[Provider] Notifikasi dimuat ulang: Ditemukan ${_notifications.length} notifikasi, ${_unreadCount} belum dibaca.');
    
    notifyListeners();
  }
  
  // Method _loadUnreadCount tidak lagi diperlukan secara terpisah karena sudah digabung
  // ke dalam loadNotifications() untuk memastikan konsistensi data.
  
  Future<void> _saveUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, _unreadCount);
  }

  Future<void> addNotification(RemoteMessage message) async {
    final newNotification = NotificationModel.fromRemoteMessage(message);

    if (newNotification.messageId != null && _notifications.any((n) => n.messageId == newNotification.messageId)) {
      debugPrint('[Provider] AddNotification DITOLAK: Duplikat messageId: ${newNotification.messageId}');
      return;
    }
    
    debugPrint('[Provider] AddNotification DITERIMA: Menambahkan messageId: ${newNotification.messageId}');
    _notifications.insert(0, newNotification);
    
    if (_notifications.length > 50) {
      _notifications.removeLast();
    }
    
    _unreadCount++;
    await _saveUnreadCount();
    
    await _saveNotifications();
    notifyListeners();
  }
  
  Future<void> markAsRead() async {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    await _saveUnreadCount();
    notifyListeners();
  }
  
  Future<void> clearNotifications() async {
    _notifications.clear();
    _unreadCount = 0;
    await _saveNotifications();
    await _saveUnreadCount();
    debugPrint('[Provider] Notifikasi dibersihkan.');
    notifyListeners();
  }
  
  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notificationsJson =
        _notifications.map((notif) => json.encode(notif.toJson())).toList();
    await prefs.setStringList(_historyKey, notificationsJson);
  }
}