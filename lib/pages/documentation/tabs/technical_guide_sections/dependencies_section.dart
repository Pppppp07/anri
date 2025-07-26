import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class DependenciesSection extends StatelessWidget {
  const DependenciesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.inventory_2_outlined,
      iconColor: Colors.lightBlue,
      title: 'Dependensi & Package Kunci',
      children: [
        DependencyCard(
          packageName: 'provider',
          description: 'Digunakan sebagai solusi utama untuk manajemen state. Memungkinkan pemisahan UI dari logika bisnis secara efisien.',
        ),
        DependencyCard(
          packageName: 'http',
          description: 'Fondasial untuk melakukan panggilan jaringan (HTTP requests) ke API backend untuk mengambil dan mengirim data.',
        ),
        DependencyCard(
          packageName: 'shared_preferences',
          description: 'Digunakan untuk menyimpan data sederhana secara persisten di perangkat, seperti token sesi pengguna atau preferensi pengaturan.',
        ),
        DependencyCard(
          packageName: 'intl',
          description: 'Bermanfaat untuk format tanggal, waktu, dan angka agar sesuai dengan lokalisasi atau standar tampilan yang diinginkan.',
        ),
        DependencyCard(
          packageName: 'firebase_core & firebase_messaging',
          description: 'Integrasi fundamental dengan Firebase untuk menginisialisasi layanan dan menangani penerimaan notifikasi push dari server.',
        ),
        DependencyCard(
          packageName: 'flutter_dotenv',
          description: 'Digunakan untuk memuat variabel lingkungan (environment variables) dari file .env. Ini berguna untuk memisahkan konfigurasi sensitif seperti URL API dari kode sumber.',
        ),
      ],
    );
  }
}