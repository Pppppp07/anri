import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class ArchitectureSection extends StatelessWidget {
  const ArchitectureSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.architecture,
      iconColor: Colors.deepPurple,
      title: 'Arsitektur & Alur Data',
      initiallyExpanded: true, // Dibuat terbuka secara default
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
    );
  }
}