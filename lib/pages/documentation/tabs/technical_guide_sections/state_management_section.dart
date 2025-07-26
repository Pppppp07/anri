import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class StateManagementSection extends StatelessWidget {
  const StateManagementSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.manage_history_outlined,
      iconColor: Color(0xFF0288D1),
      title: 'Manajemen State (Provider)',
      children: [
        FeatureDetail(
          title: 'Prinsip Utama',
          description:
              'Aplikasi menggunakan Provider untuk memisahkan antara logika bisnis (business logic) dan tampilan (UI). ChangeNotifierProvider digunakan untuk "menyediakan" instance class Notifier ke widget tree, dan Consumer atau context.watch digunakan untuk "mendengarkan" perubahan dan membangun ulang UI saat data berubah.',
        ),
        ProviderDetailCard(
            providerName: 'AuthProvider',
            description: '• **Tanggung Jawab**: Mengelola status autentikasi pengguna (login, logout), menyimpan dan mengambil data pengguna serta token sesi dari `shared_preferences`.\n'
                '• **Metode Kunci**: `login()`, `logout()`, `tryAutoLogin()`.'),
        ProviderDetailCard(
            providerName: 'TicketProvider',
            description: '• **Tanggung Jawab**: Mengelola semua state yang berkaitan dengan tiket, termasuk memuat daftar tiket, detail tiket, mengirim balasan, dan mengubah atribut tiket.\n'
                '• **Metode Kunci**: `fetchTickets()`, `fetchTicketDetails()`, `addReply()`, `updateTicket()`.'),
        ProviderDetailCard(
            providerName: 'AppDataProvider',
            description: '• **Tanggung Jawab**: Memuat dan menyimpan data master atau data "global" yang jarang berubah, seperti daftar kategori, daftar staf, dan status tiket.\n'
                '• **Metode Kunci**: `fetchInitialData()`.'),
        ProviderDetailCard(
            providerName: 'ThemeProvider',
            description: '• **Tanggung Jawab**: Mengelola tema aplikasi saat ini (terang atau gelap) dan menyimpannya ke `shared_preferences`.\n'
                '• **Metode Kunci**: `toggleTheme()`.'),
      ],
    );
  }
}