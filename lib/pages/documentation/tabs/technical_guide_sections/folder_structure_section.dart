import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class FolderStructureSection extends StatelessWidget {
  const FolderStructureSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.folder_open_outlined,
      iconColor: Colors.amber,
      title: 'Struktur Folder Proyek',
      children: [
        FeatureDetail(
          title: '📂 lib/',
          description: 'Direktori utama yang berisi semua kode sumber aplikasi Dart.',
        ),
        ProjectStructureItem(
          folderName: 'config/',
          description: 'Menyimpan file konfigurasi global, seperti endpoint URL API (`api_config.dart`).',
        ),
        ProjectStructureItem(
          folderName: 'models/',
          description: 'Berisi kelas-kelas model data (misalnya, `Ticket`, `Reply`) yang merepresentasikan struktur data dari respons API.',
        ),
        ProjectStructureItem(
          folderName: 'pages/ atau screens/',
          description: 'Setiap file di sini merepresentasikan satu layar atau halaman di aplikasi. Folder ini juga bisa berisi sub-direktori untuk widget yang spesifik untuk halaman tersebut.',
        ),
        ProjectStructureItem(
          folderName: 'providers/',
          description: 'Inti dari manajemen state. Berisi semua `ChangeNotifier` yang mengelola logika bisnis dan state aplikasi.',
        ),
        ProjectStructureItem(
          folderName: 'services/',
          description: 'Berisi kelas-kelas yang menyediakan layanan spesifik, seperti komunikasi dengan API (misalnya, `api_service.dart`) atau integrasi Firebase (`firebase_api.dart`).',
        ),
        ProjectStructureItem(
          folderName: 'utils/',
          description: 'Kumpulan fungsi atau kelas utilitas yang dapat digunakan kembali di seluruh aplikasi, contohnya `error_handler.dart`.',
        ),
        ProjectStructureItem(
          folderName: 'widgets/',
          description: 'Menyimpan widget kustom yang bersifat umum dan digunakan di lebih dari satu halaman (contoh: `CustomButton`, `LoadingIndicator`).',
        ),
      ],
    );
  }
}