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
    _loadUnreadCount();
  }

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notificationsJson = prefs.getStringList(_historyKey) ?? [];
    _notifications.clear();
    _notifications.addAll(notificationsJson
        .map((jsonString) => NotificationModel.fromJson(json.decode(jsonString)))
        .toList());
        debugPrint('[Provider] LoadNotifications: Ditemukan ${_notifications.length} notifikasi tersimpan.');
    notifyListeners();
  }
  
  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;
    notifyListeners();
  }
  
  Future<void> _saveUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, _unreadCount);
  }

  Future<void> addNotification(RemoteMessage message) async {
    final newNotification = NotificationModel.fromRemoteMessage(message);

    // --- [PERBAIKAN UTAMA DI SINI] ---
    // Cek apakah notifikasi dengan messageId yang sama sudah ada.
    // Ini akan secara efektif mencegah duplikasi dari race condition.
    if (newNotification.messageId != null && _notifications.any((n) => n.messageId == newNotification.messageId)) {
      debugPrint('[Provider] AddNotification DITOLAK: Duplikat messageId: ${newNotification.messageId}');
      return; // Hentikan fungsi jika duplikat ditemukan.
    }
    // --- [AKHIR BLOK PERBAIKAN] ---
    
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