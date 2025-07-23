import 'package:anri/models/notification_model.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:anri/services/firebase_api.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// --- UBAH MENJADI STATEFULWIDGET ---
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    // Panggil setelah frame pertama selesai dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Saat halaman ini dibuka, reset hitungan notifikasi belum dibaca
      context.read<NotificationProvider>().markAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan Consumer untuk mendapatkan data dari NotificationProvider
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifikasi'),
            elevation: 1,
            actions: [
              // Tambahkan tombol untuk menghapus semua notifikasi
              if (provider.notifications.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Hapus Semua',
                  onPressed: () {
                    // Tampilkan dialog konfirmasi sebelum menghapus
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Riwayat'),
                        content: const Text('Apakah Anda yakin ingin menghapus semua riwayat notifikasi?'),
                        actions: [
                          TextButton(
                            child: const Text('Batal'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          FilledButton(
                            child: const Text('Hapus'),
                            onPressed: () {
                              provider.clearNotifications();
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: provider.notifications.isEmpty
              ? _buildEmptyState() // Tampilkan state kosong jika tidak ada notifikasi
              : _buildNotificationList(provider.notifications), // Tampilkan list jika ada
        );
      },
    );
  }

  // Widget untuk menampilkan daftar notifikasi
  Widget _buildNotificationList(List<NotificationModel> notifications) {
    final timeFormat = DateFormat('HH:mm');

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return ListTile(
          leading: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
          title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(notif.body),
          trailing: Text(timeFormat.format(notif.receivedAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          onTap: () {
            // Saat di-tap, panggil handleMessage untuk membuka detail tiket
    FirebaseApi().navigateToTicketDetail(notif.ticketId);
          },
        );
      },
    );
  }

  // Widget untuk state kosong (kode dari file asli Anda)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Notifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notifikasi baru terkait tiket Anda akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}