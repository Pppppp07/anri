import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class ThemingSection extends StatelessWidget {
  const ThemingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.palette_outlined,
      iconColor: Colors.pinkAccent,
      title: 'Theming & Kustomisasi UI',
      children: [
        FeatureDetail(
          title: 'Manajemen Tema Terpusat',
          description:
              'Aplikasi menggunakan `ThemeProvider` (`lib/providers/theme_provider.dart`) untuk mengelola tema aplikasi. Ini memungkinkan pengguna untuk beralih antara mode terang (light mode) dan mode gelap (dark mode) secara dinamis. Preferensi tema juga disimpan di `shared_preferences` agar tetap konsisten saat aplikasi dibuka kembali.',
        ),
        FeatureDetail(
          title: 'Bagaimana Cara Mengubah Warna?',
          description:
              'Untuk mengubah skema warna utama, modifikasi objek `ThemeData` di dalam file `theme_provider.dart`. Ubah nilai `primaryColor`, `colorScheme`, `scaffoldBackgroundColor`, dll., pada `lightTheme` dan `darkTheme`. Semua widget yang menggunakan `Theme.of(context)` akan otomatis beradaptasi.',
        ),
        FeatureDetail(
          title: 'Mengubah Font',
          description:
              '1. Tambahkan file font (misal: .ttf) ke dalam folder `assets/fonts/`.\n'
              '2. Daftarkan font tersebut di file `pubspec.yaml`.\n'
              '3. Atur properti `fontFamily` pada `ThemeData` di `theme_provider.dart` untuk menetapkan font default aplikasi.',
        ),
      ],
    );
  }
}