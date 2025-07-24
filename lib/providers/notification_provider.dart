import 'dart:convert';
import 'package:anri/models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  final String _historyKey = 'notification_history';
  // Kunci _unreadCountKey tidak lagi diperlukan

  final List<NotificationModel> _notifications = [];

  List<NotificationModel> get notifications => _notifications;
  
  // --- PERBAIKAN: Ubah unreadCount menjadi getter dinamis ---
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    debugPrint('[Provider] NotificationProvider Dibuat.');
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    final List<String> notificationsJson = prefs.getStringList(_historyKey) ?? [];
    _notifications.clear();
    _notifications.addAll(notificationsJson
        .map((jsonString) => NotificationModel.fromJson(json.decode(jsonString)))
        .toList());
        
    debugPrint('[Provider] Notifikasi dimuat ulang: Ditemukan ${_notifications.length} notifikasi, ${unreadCount} belum dibaca.');
    notifyListeners();
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
    
    await _saveNotifications();
    notifyListeners();
  }
  
  // --- FUNGSI BARU: Untuk menandai satu notifikasi sebagai telah dibaca ---
  Future<void> markOneAsRead(NotificationModel notification) async {
    final index = _notifications.indexWhere((n) => n.messageId == notification.messageId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      await _saveNotifications();
      notifyListeners();
    }
  }
  
  Future<void> clearNotifications() async {
    _notifications.clear();
    await _saveNotifications();
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