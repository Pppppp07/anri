import 'dart:convert';
import 'package:anri/models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  final String _historyKey = 'notification_history';
  final String _unreadCountKey = 'notification_unread_count';

  // Mengikuti saran linter untuk praktik terbaik
  final List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  NotificationProvider() {
    debugPrint('[Provider] NotificationProvider Dibuat.'); // <-- Tambahkan ini
    loadNotifications();
    _loadUnreadCount();
  }

  // Memuat notifikasi dari penyimpanan lokal
  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    // PERBAIKAN: Menggunakan _historyKey yang benar
    final List<String> notificationsJson = prefs.getStringList(_historyKey) ?? [];
    // Hapus data lama sebelum memuat yang baru
    _notifications.clear();
    _notifications.addAll(notificationsJson
        .map((jsonString) => NotificationModel.fromJson(json.decode(jsonString)))
        .toList());
        debugPrint('[Provider] LoadNotifications: Ditemukan ${_notifications.length} notifikasi tersimpan.');
    notifyListeners();
  }
  
  // Memuat jumlah notif belum dibaca dari penyimpanan
  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;
    notifyListeners();
  }
  
  // Menyimpan jumlah notif belum dibaca ke penyimpanan
  Future<void> _saveUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, _unreadCount);
  }

  // Menambah notifikasi baru dan menyimpannya
  Future<void> addNotification(RemoteMessage message) async {
      debugPrint('[Provider] AddNotification: Fungsi dipanggil.');
    final newNotification = NotificationModel.fromRemoteMessage(message);
    _notifications.insert(0, newNotification);
    
    if (_notifications.length > 50) {
      _notifications.removeLast();
    }
    
    _unreadCount++;
    await _saveUnreadCount();
    
    await _saveNotifications();
    notifyListeners();
  }
  
  // Menandai semua notifikasi sebagai sudah dibaca
  Future<void> markAsRead() async {
    if (_unreadCount == 0) return; // Optimasi: jangan lakukan apa-apa jika sudah 0
    _unreadCount = 0;
    await _saveUnreadCount();
    notifyListeners();
  }
  
  // Menghapus semua notifikasi
  Future<void> clearNotifications() async {
    _notifications.clear();
    _unreadCount = 0;
    await _saveNotifications();
    await _saveUnreadCount();
      debugPrint('[Provider] AddNotification: Notifikasi disimpan. Jumlah sekarang: ${_notifications.length}. Belum dibaca: $_unreadCount');

    notifyListeners();
  }
  
  // Menyimpan list notifikasi ke SharedPreferences
  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notificationsJson =
        _notifications.map((notif) => json.encode(notif.toJson())).toList();
    // PERBAIKAN: Menggunakan _historyKey yang benar
    await prefs.setStringList(_historyKey, notificationsJson);
  }
}