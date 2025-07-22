import 'package:flutter/material.dart';
import '../widgets/header_card.dart';
import '../widgets/content_widgets.dart';
import '../widgets/animated_widgets.dart';

class UserGuideTab extends StatelessWidget {
  const UserGuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StaggeredListView(
      children: const [
        HeaderCard(
          title: 'Panduan Pengguna',
          subtitle: 'Semua yang perlu Anda ketahui untuk menggunakan aplikasi ini secara efektif.',
        ),
        DocumentationTile(
          icon: Icons.account_tree_outlined,
          iconColor: Colors.blue,
          title: 'Alur Kerja Tiket (Workflow)',
          initiallyExpanded: true,
          children: [
             StepTile(step: '1', title: 'Tiket Masuk', description: 'Setiap laporan baru akan muncul di Beranda dengan status "New". Notifikasi push juga akan dikirim ke staf yang relevan.'),
             StepTile(step: '2', title: 'Penugasan (Assignment)', description: 'Tiket dapat ditugaskan ke staf spesifik. Anda bisa mengambil tiket untuk diri sendiri melalui tombol "Tugaskan ke Saya" di halaman detail.'),
             StepTile(step: '3', title: 'Pengerjaan & Komunikasi', description: 'Gunakan fitur "Riwayat & Balas" untuk berkomunikasi dengan pelanggan dan mencatat progres. Lacak waktu kerja menggunakan fitur stopwatch.'),
             StepTile(step: '4', title: 'Penyelesaian (Resolve)', description: 'Setelah masalah teratasi, ubah status tiket menjadi "Resolved". Tiket yang selesai akan otomatis berpindah ke tab "Riwayat".'),
          ],
        ),
        DocumentationTile(
          icon: Icons.palette_outlined,
          iconColor: Colors.teal,
          title: 'Legenda & Indikator Visual',
          children: [
            LegendItem(color: Color(0xFFD32F2F), label: 'New: Tiket baru, belum ada tindakan.'),
            LegendItem(color: Color(0xFFE65100), label: 'Waiting Reply: Menunggu balasan dari pelanggan.'),
            LegendItem(color: Color(0xFF1976D2), label: 'Replied: Anda sudah membalas, menunggu respons pelanggan.'),
            LegendItem(color: Color(0xFF673AB7), label: 'In Progress: Tiket sedang dalam proses pengerjaan.'),
            LegendItem(color: Color(0xFFC2185B), label: 'On Hold: Pengerjaan tiket ditunda sementara.'),
            LegendItem(color: Color(0xFF388E3C), label: 'Resolved: Tiket sudah selesai dan ditutup.'),
            Divider(height: 24),
            LegendItem(icon: Icons.person, color: Colors.blue, label: 'Tiket ditugaskan kepada Anda.'),
            LegendItem(icon: Icons.group_outlined, color: Colors.grey, label: 'Tiket ditugaskan ke staf lain.'),
            LegendItem(icon: Icons.person_add_disabled_outlined, color: Colors.grey, label: 'Tiket belum ditugaskan (Unassigned).'),
          ],
        ),
         DocumentationTile(
            icon: Icons.quiz_outlined,
            iconColor: Colors.cyan,
            title: 'Penyelesaian Masalah (FAQ)',
            children: [
              FaqItem(question: 'Mengapa saya tidak menerima notifikasi?', answer: 'Pastikan Anda telah memberikan izin notifikasi untuk aplikasi ini di pengaturan perangkat Anda. Cek juga koneksi internet Anda. Jika masih bermasalah, coba logout dan login kembali untuk me-refresh token notifikasi Anda.'),
              FaqItem(question: 'Apa fungsi "Hapus Cache"?', answer: 'Fitur ini akan menghapus semua data sesi (termasuk login) dan pengaturan yang tersimpan di perangkat. Ini berguna jika aplikasi terasa lambat atau mengalami error yang tidak biasa. Anda akan diminta untuk login kembali setelahnya.'),
               FaqItem(question: 'Bagaimana jika saya lupa password?', answer: 'Fitur reset password saat ini hanya tersedia di versi web HESK. Silakan akses HESK melalui browser untuk melakukan reset password.'),
            ],
          ),
      ],
    );
  }
}