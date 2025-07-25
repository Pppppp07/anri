import 'package:anri/models/notification_model.dart';
import 'package:anri/providers/notification_provider.dart';
import 'package:anri/services/firebase_api.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifikasi'),
            elevation: 1,
            actions: [
              if (provider.notifications.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Hapus Semua',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Riwayat'),
                        content: const Text(
                          'Apakah Anda yakin ingin menghapus semua riwayat notifikasi?',
                        ),
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
              ? _buildEmptyState()
              : _buildNotificationList(provider),
        );
      },
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    final timeFormat = DateFormat('HH:mm');
    final notifications = provider.notifications;

    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notif = notifications.elementAt(index);
        return Stack(
          // 1. Bungkus ListTile dengan Stack
          children: [
            ListTile(
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.blueAccent,
              ),
              title: Text(
                notif.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(notif.body),
              trailing: Text(
                timeFormat.format(
                  notif.receivedAt,
                ), // 2. Trailing sekarang hanya berisi Text
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                provider.markOneAsRead(notif);
                FirebaseApi().navigateToTicketDetail(notif.ticketId);
              },
            ),
            if (!notif.isRead)
              Positioned(
                // 3. Positioned sekarang berada di dalam Stack utama
                top: 12, // Sesuaikan posisi vertikal
                right: 12, // Sesuaikan posisi horizontal
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
