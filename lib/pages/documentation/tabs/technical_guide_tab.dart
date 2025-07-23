import 'package:flutter/material.dart';
import '../widgets/content_widgets.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/header_card.dart';

class TechnicalGuideTab extends StatelessWidget {
  const TechnicalGuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StaggeredListView(
      children: const [
        HeaderCard(
          title: 'Dokumentasi Teknis Mendalam',
          subtitle: 'Detail arsitektur, struktur, dan alur data untuk pengembang selanjutnya.',
        ),
        DocumentationTile(
          icon: Icons.architecture,
          iconColor: Colors.deepPurple,
          title: 'Arsitektur & Alur Data',
          initiallyExpanded: true,
          children: [
            FeatureDetail(
              title: '🏛️ Pola Arsitektur',
              description:
                  'Aplikasi ini mengadopsi pendekatan arsitektur berlapis (Layered Architecture) yang dipadukan dengan pola manajemen state Provider. Tujuannya adalah memisahkan dengan jelas antara concern UI, Logika Bisnis, dan Akses Data.',
            ),
            Divider(height: 24, thickness: 0.5),
            ArchitecturalComponentCard(
              icon: Icons.view_quilt_outlined,
              iconColor: Colors.blue,
              title: 'View Layer (UI)',
              description: 'Terdiri dari semua Widget Flutter. Bertanggung jawab murni untuk presentasi dan menangkap input pengguna. Contoh: TicketCard, TicketDetailScreen.',
            ),
            ArchitecturalComponentCard(
              icon: Icons.manage_history_outlined,
              iconColor: Colors.orange,
              title: 'State Management Layer (Provider)',
              description: 'Menjembatani View dan Data Layer. Berisi Notifier (misal: TicketProvider) yang memegang state dan logika bisnis. Memberi notifikasi ke UI jika ada perubahan data.',
            ),
            ArchitecturalComponentCard(
              icon: Icons.miscellaneous_services_outlined,
              iconColor: Colors.green,
              title: 'Service Layer',
              description: 'Menangani komunikasi dengan dunia luar, terutama panggilan API ke backend. Dibuat terisolasi agar mudah diganti atau diuji. Contoh: ApiService.',
            ),
            ArchitecturalComponentCard(
              icon: Icons.data_object_outlined,
              iconColor: Colors.red,
              title: 'Data Layer (Model & API)',
              description: 'Terdiri dari Model class (misal: Ticket, Reply) yang merepresentasikan struktur data JSON dari API, dan endpoint PHP di backend yang berinteraksi langsung dengan database.',
            ),
            Divider(height: 24, thickness: 0.5),
            DataFlowStep(
              step: '1',
              icon: Icons.touch_app_outlined,
              actor: 'Pengguna',
              action: 'Membuka aplikasi atau melakukan pull-to-refresh di halaman Beranda.',
            ),
            DataFlowStep(
              step: '2',
              icon: Icons.layers_outlined,
              actor: 'Widget (View)',
              action: 'Memanggil fungsi fetchTickets() dari TicketProvider. Contoh: context.read<TicketProvider>().fetchTickets();',
            ),
            DataFlowStep(
              step: '3',
              icon: Icons.sync_alt_outlined,
              actor: 'TicketProvider',
              action: 'Mengubah status loading menjadi true (notifyListeners()), lalu memanggil ApiService untuk melakukan request HTTP GET ke endpoint /get_tickets.php.',
            ),
            DataFlowStep(
              step: '4',
              icon: Icons.dns_outlined,
              actor: 'API Backend (PHP)',
              action: 'Menerima request, melakukan query ke database MySQL, dan mengembalikan data tiket dalam format JSON.',
            ),
            DataFlowStep(
              step: '5',
              icon: Icons.code_outlined,
              actor: 'TicketProvider',
              action: 'Menerima JSON, mem-parsingnya menjadi List<Ticket>, memperbarui state internal, dan mengubah status loading menjadi false, lalu memanggil notifyListeners() untuk terakhir kalinya.',
            ),
            DataFlowStep(
              step: '6',
              icon: Icons.palette_outlined,
              actor: 'Widget (View)',
              action: 'Karena mendengarkan provider (via Consumer atau context.watch), UI secara otomatis membangun ulang dirinya sendiri (rebuild) untuk menampilkan daftar tiket yang baru.',
              isLastStep: true,
            ),
          ],
        ),
        DocumentationTile(
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
              description: '(Opsional, jika ada) Menyimpan widget kustom yang bersifat umum dan digunakan di lebih dari satu halaman (contoh: `CustomButton`, `LoadingIndicator`).',
            ),
          ],
        ),
        DocumentationTile(
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
              description: 'Digunakan untuk menyimpan data sederhana secara persisten di perangkat, seperti token sesi pengguna atau preferensi pengaturan (misalnya tema gelap/terang).',
            ),
            DependencyCard(
              packageName: 'intl',
              description: 'Bermanfaat untuk format tanggal, waktu, dan angka agar sesuai dengan lokalisasi atau standar tampilan yang diinginkan.',
            ),
            DependencyCard(
              packageName: 'firebase_core & firebase_messaging',
              description: 'Integrasi fundamental dengan Firebase untuk menginisialisasi layanan dan menangani penerimaan notifikasi push dari server.',
            ),
          ],
        ),
        DocumentationTile(
          icon: Icons.palette_outlined,
          iconColor: Colors.pinkAccent,
          title: 'Theming & Kustomisasi UI',
          children: [
            FeatureDetail(
              title: 'Manajemen Tema Terpusat',
              description:
                  'Aplikasi menggunakan `ThemeProvider` (`lib/providers/theme_provider.dart`) untuk mengelola tema aplikasi. Ini memungkinkan pengguna untuk beralih antara mode terang (light mode) dan mode gelap (dark mode) secara dinamis.',
            ),
            FeatureDetail(
              title: 'Bagaimana Cara Mengubah Warna?',
              description:
                  'Untuk mengubah skema warna utama, modifikasi objek `ThemeData` di dalam file `theme_provider.dart`. Ubah nilai `primaryColor`, `accentColor` (atau `colorScheme`), `scaffoldBackgroundColor`, dll., pada `lightTheme` dan `darkTheme`. Semua widget yang menggunakan `Theme.of(context)` akan otomatis beradaptasi.',
            ),
            FeatureDetail(
              title: 'Mengubah Font',
              description:
                  '1. Tambahkan file font (misal: .ttf) ke dalam folder `assets/fonts/`.\n'
                  '2. Daftarkan font tersebut di file `pubspec.yaml`.\n'
                  '3. Atur properti `fontFamily` pada `ThemeData` di `theme_provider.dart` untuk menetapkan font default aplikasi.',
            ),
          ],
        ),
        DocumentationTile(
          icon: Icons.manage_history_outlined,
          iconColor: Color(0xFF0288D1),
          title: 'Manajemen State (Provider)',
          children: [
             FeatureDetail(
              title: 'Prinsip Utama',
              description: 'Aplikasi menggunakan Provider untuk memisahkan antara logika bisnis (business logic) dan tampilan (UI). ChangeNotifierProvider digunakan untuk "menyediakan" instance class Notifier ke widget tree, dan Consumer atau context.watch digunakan untuk "mendengarkan" perubahan dan membangun ulang UI saat data berubah.',
            ),
            ProviderDetailCard(
              providerName: 'AuthProvider',
              description: '• **Tanggung Jawab**: Mengelola status autentikasi pengguna (login, logout), menyimpan dan mengambil data pengguna serta token sesi dari `shared_preferences`.\n'
                           '• **Metode Kunci**: `login()`, `logout()`, `tryAutoLogin()`.'
            ),
            ProviderDetailCard(
              providerName: 'TicketProvider',
              description: '• **Tanggung Jawab**: Mengelola semua state yang berkaitan dengan tiket, termasuk memuat daftar tiket, detail tiket, mengirim balasan, dan mengubah atribut tiket.\n'
                           '• **Metode Kunci**: `fetchTickets()`, `fetchTicketDetails()`, `addReply()`, `updateTicket()`.'
            ),
             ProviderDetailCard(
              providerName: 'AppDataProvider',
              description: '• **Tanggung Jawab**: Memuat dan menyimpan data master atau data "global" yang jarang berubah, seperti daftar kategori, daftar staf, dan status tiket.\n'
                           '• **Metode Kunci**: `fetchInitialData()`.'
            ),
          ],
        ),
        DocumentationTile(
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
              tableName: 'hesk_users',
              description: 'Tabel staf. Kolom penting:\n'
                           '• `id` (PK), `user`, `pass`: Kredensial login.\n'
                           '• `name`: Nama lengkap staf yang ditampilkan di aplikasi.\n'
                           '• `categories`: Daftar ID kategori yang bisa diakses oleh staf.\n'
                           '• `isadmin`: Menentukan hak akses admin.\n'
                           '• `fcm_token`: Token Firebase unik per perangkat untuk target notifikasi.',
            ),
             DatabaseTableCard(
              tableName: 'hesk_categories',
              description: 'Menyimpan daftar kategori atau departemen. Digunakan untuk filter dan penugasan otomatis.',
            ),
             DatabaseTableCard(
              tableName: 'hesk_auth_tokens',
              description: 'Tabel kustom untuk sesi API. Kolom penting:\n'
                           '• `selector` (Unique), `hashedValidator`: Pasangan untuk verifikasi token yang aman.\n'
                           '• `userid` (FK ke hesk_users.id): Menghubungkan token ke pengguna.\n'
                           '• `expires`: Timestamp kedaluwarsa token.',
            ),
          ],
        ),
        DocumentationTile(
          icon: Icons.http_outlined,
          iconColor: Colors.orange,
          title: 'Dokumentasi API Endpoint',
          children: [
            ApiEndpointCard(
              method: 'GET',
              endpoint: '/get_app_data.php',
              description: 'Mengambil data master yang dibutuhkan aplikasi saat startup, seperti daftar kategori, daftar semua staf, dan daftar status tiket.',
              responseBody: '{\n  "success": true,\n  "categories": [...],\n  "staff": [...],\n  "statuses": [...]\n}',
            ),
             ApiEndpointCard(
              method: 'POST',
              endpoint: '/update_ticket_details.php',
              description: 'Memperbarui atribut spesifik dari sebuah tiket, seperti status, prioritas, atau pemilik (assignee).',
              requestBody: '{\n  "ticket_id": 123,\n  "new_status": "3",\n  "new_owner": "5",\n  "new_priority": "1"\n}',
              responseBody: '{\n  "success": true,\n  "message": "Tiket berhasil diperbarui."\n}',
            ),
            ApiEndpointCard(
              method: 'CONTOH ERROR',
              endpoint: '/get_tickets.php',
              description: 'Contoh respons ketika terjadi error, misalnya token tidak valid atau parameter hilang.',
              responseBody: '{\n  "success": false,\n  "message": "Autentikasi gagal: Token tidak valid atau kedaluwarsa."\n}',
              isError: true,
            ),
          ],
        ),
        DocumentationTile(
          icon: Icons.error_outline,
          iconColor: Colors.pink,
          title: 'Strategi Penanganan Error (Error Handling)',
          children: [
            FeatureDetail(
              title: 'Error API',
              description: 'Setiap respons dari API memiliki kunci `success` (boolean). Jika `false`, aplikasi akan menampilkan pesan error yang dikirim dalam kunci `message` dari API menggunakan `SnackBar` atau dialog. Ini memastikan pesan error yang ditampilkan ke pengguna relevan dan informatif.',
            ),
            FeatureDetail(
              title: 'Error Konektivitas',
              description: 'Sebelum melakukan panggilan API, aplikasi dapat memeriksa konektivitas jaringan. Jika tidak ada koneksi, panggilan API akan dibatalkan dan sebuah pesan "Tidak ada koneksi internet" akan ditampilkan kepada pengguna.',
            ),
            FeatureDetail(
              title: 'Error Parsing',
              description: 'Dibungkus dalam blok `try-catch`. Jika terjadi kegagalan saat mem-parsing JSON (misalnya, format tidak sesuai dengan model Dart), aplikasi akan mencatat error tersebut (logging) dan menampilkan pesan error umum untuk mencegah aplikasi crash.',
            ),
          ],
        ),
        SizedBox(height: 24),
        ContactButton(),
        SizedBox(height: 16),
      ],
    );
  }
}