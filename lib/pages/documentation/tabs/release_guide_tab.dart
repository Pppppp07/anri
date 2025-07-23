import 'package:flutter/material.dart';
import '../widgets/header_card.dart';
import '../widgets/content_widgets.dart';
import '../widgets/animated_widgets.dart';

class ReleaseGuideTab extends StatelessWidget {
  const ReleaseGuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StaggeredListView(
      children: const [
        HeaderCard(
          title: 'Panduan Rilis & Kredit',
          subtitle: 'Informasi tim pengembang dan langkah-langkah untuk merilis versi baru aplikasi.',
        ),
         DocumentationTile(
          icon: Icons.checklist_rtl_outlined,
          iconColor: Colors.green,
          title: 'Checklist Persiapan Rilis',
          initiallyExpanded: true,
          children: [
            ReleaseChecklistItem(isDone: true, text: 'Pastikan file `.env` diisi dengan URL API produksi.'),
            ReleaseChecklistItem(isDone: false, text: 'Ganti Application ID di `build.gradle.kts` dari "com.example.anri" ke ID resmi (misal: id.go.anri.helpdesk).'),
            ReleaseChecklistItem(isDone: false, text: 'Perbarui `version` di `pubspec.yaml` (misal: 1.0.1+2).'),
            ReleaseChecklistItem(isDone: true, text: 'Hapus semua statement `debugPrint()` dari kode.'),
            ReleaseChecklistItem(isDone: false, text: 'Ganti ikon aplikasi di `android` dan `ios` dengan aset final dari ANRI.'),
            ReleaseChecklistItem(isDone: false, text: 'Pastikan file `google-services.json` dan `service-account-key.json` menggunakan konfigurasi Firebase produksi.'),
          ],
        ),
         DocumentationTile(
          icon: Icons.terminal_outlined,
          iconColor: Colors.blueGrey,
          title: 'Perintah Build (CLI)',
          children: [
            FeatureDetail(
              title: 'Build Android (APK)',
              description: 'Jalankan perintah berikut di terminal dari root proyek:\n`flutter build apk --release`\n\nHasilnya akan berada di `build/app/outputs/flutter-apk/app-release.apk`.'
            ),
             FeatureDetail(
              title: 'Build iOS',
              description: 'Jalankan perintah berikut di terminal (membutuhkan macOS & Xcode):\n`flutter build ios --release`\n\nBuka `ios/Runner.xcworkspace` di Xcode untuk mengarsipkan dan mendistribusikan aplikasi.'
            ),
          ],
        ),
        DocumentationTile(
          icon: Icons.history_edu_outlined,
          iconColor: Colors.indigo,
          title: 'Proses & Tim Pengembangan',
          children: [
            FeatureDetail(title: 'Latar Belakang', description: 'Aplikasi ini dikembangkan sebagai bagian dari program magang [Nama Program Magang/Universitas Anda] di Arsip Nasional Republik Indonesia pada tahun 2025.'),
            FeatureDetail(title: 'Tim Pengembang (Magang)', description: '[Nama Lengkap Anda]\n[Nama Lengkap Anggota Tim 2]\n[Nama Lengkap Anggota Tim 3]'),
            FeatureDetail(title: 'Pembimbing', description: '[Nama Lengkap Pembimbing/Mentor di ANRI]'),
            FeatureDetail(title: 'Hak Cipta', description: '© 2025 Arsip Nasional Republik Indonesia. Seluruh hak cipta atas kode sumber dan aset aplikasi ini dimiliki oleh ANRI.'),
          ],
        ),
      ],
    );
  }
}