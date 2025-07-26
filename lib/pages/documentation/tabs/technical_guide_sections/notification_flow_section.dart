import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class NotificationFlowSection extends StatelessWidget {
  const NotificationFlowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.notifications_active_outlined,
      iconColor: Colors.teal,
      title: 'Alur Kerja Notifikasi (Push, Email, Telegram)',
      children: [
        FeatureDetail(
          title: '🎯 Tujuan Notifikasi',
          description:
              'Sistem notifikasi dirancang untuk memberi tahu staf secara proaktif tentang tiket baru atau balasan pelanggan, memastikan respons yang cepat. Aplikasi ini mendukung tiga kanal: Firebase Cloud Messaging (FCM), Email, dan Telegram.',
        ),
        Divider(height: 24, thickness: 0.5),
        DataFlowStep(
          step: '1',
          icon: Icons.send_and_archive_outlined,
          actor: 'Pemicu (Trigger)',
          action: 'Sebuah event terjadi di sistem HESK, misalnya pelanggan membuat tiket baru atau mengirim balasan. Ini memanggil fungsi kustom `anri_custom_notify_staff` di dalam `anri_custom_functions.inc.php`.',
        ),
        DataFlowStep(
          step: '2',
          icon: Icons.http_outlined,
          actor: 'HESK Backend',
          action: 'Fungsi PHP tersebut kemudian memanggil endpoint `send_notification.php` di API kustom, dengan membawa detail tiket yang relevan.',
        ),
        DataFlowStep(
          step: '3',
          icon: Icons.hub_outlined,
          actor: 'API `send_notification.php`',
          action: 'Endpoint ini bertindak sebagai pusat notifikasi. Ia mengambil token FCM, alamat email, dan ID chat Telegram dari staf yang relevan dari database (tabel `hesk_users`).',
        ),
        DataFlowStep(
          step: '4a',
          icon: Icons.mobile_friendly_outlined,
          actor: 'Firebase (FCM)',
          action: 'API mengirim payload notifikasi ke server FCM, menargetkan token spesifik perangkat staf. Perangkat staf akan menampilkan notifikasi push.',
        ),
        DataFlowStep(
          step: '4b',
          icon: Icons.email_outlined,
          actor: 'PHPMailer',
          action: 'Secara paralel, API menggunakan library PHPMailer untuk mengirim email notifikasi ke alamat email staf.',
        ),
        DataFlowStep(
          step: '4c',
          icon: Icons.telegram,
          actor: 'Telegram Bot API',
          action: 'API juga mengirim pesan ke bot Telegram, yang kemudian meneruskannya ke staf melalui chat pribadi atau grup.',
          isLastStep: true,
        ),
      ],
    );
  }
}