import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class DatabaseStructureSection extends StatelessWidget {
  const DatabaseStructureSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.storage_outlined,
      iconColor: Colors.brown,
      title: 'Struktur Database Penting',
      children: [
        DatabaseTableCard(
          tableName: 'hesk_tickets',
          description: 'Tabel utama tiket. Kolom penting:\n'
              '• `id` (PK), `trackid` (Unique): Identifier tiket.\n'
              '• `category` (FK ke hesk_categories.id): Menentukan departemen atau jenis masalah.\n'
              '• `owner` (FK ke hesk_users.id): Menentukan staf yang ditugaskan saat ini.\n'
              '• `status`: Status tiket (0-New, 1-Replied, 2-Waiting Reply, 3-Resolved, dll).\n'
              '• `custom1` (Unit Kerja), `custom2` (No. HP): Kolom kustom untuk data tambahan.',
        ),
        DatabaseTableCard(
          tableName: 'hesk_replies',
          description: 'Tabel untuk menyimpan balasan pada tiket. Kolom penting:\n'
              '• `replyto` (FK ke hesk_tickets.id): Menunjukkan tiket induk.\n'
              '• `message`: Isi dari balasan.\n'
              '• `staffid` (FK ke hesk_users.id): Menunjukkan staf yang membalas.\n'
              '• `dt`: Timestamp kapan balasan dibuat.',
        ),
        DatabaseTableCard(
          tableName: 'hesk_users',
          description: 'Tabel staf. Kolom penting:\n'
              '• `id` (PK), `user`, `pass`: Kredensial login.\n'
              '• `name`: Nama lengkap staf yang ditampilkan di aplikasi.\n'
              '• `categories`: Daftar ID kategori yang bisa diakses oleh staf.\n'
              '• `isadmin`: Menentukan hak akses admin.\n'
              '• `fcm_token`: Token Firebase unik per perangkat untuk target notifikasi.\n'
              '• `telegram_id`: ID Chat Telegram unik per staf.',
        ),
        DatabaseTableCard(
          tableName: 'hesk_categories',
          description:
              'Menyimpan daftar kategori atau departemen. Digunakan untuk filter dan penugasan otomatis.',
        ),
        DatabaseTableCard(
          tableName: 'hesk_auth_tokens',
          description: 'Tabel kustom untuk sesi API. Kolom penting:\n'
              '• `selector` (Unique), `hashedValidator`: Pasangan untuk verifikasi token yang aman.\n'
              '• `userid` (FK ke hesk_users.id): Menghubungkan token ke pengguna.\n'
              '• `expires`: Timestamp kedaluwarsa token.',
        ),
      ],
    );
  }
}