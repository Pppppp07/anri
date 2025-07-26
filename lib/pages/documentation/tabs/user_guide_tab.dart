import 'package:flutter/material.dart';
import '../widgets/header_card.dart';
import '../widgets/content_widgets.dart';
import '../widgets/animated_widgets.dart';

class UserGuideTab extends StatelessWidget {
  const UserGuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StaggeredListView(
      children: [
        const HeaderCard(
          title: 'Panduan Pengguna',
          subtitle: 'Semua yang perlu Anda ketahui untuk menggunakan aplikasi ini secara efektif.',
        ),
        DocumentationTile(
          icon: Icons.account_tree_outlined,
          iconColor: Colors.blue,
          title: 'Alur Kerja Tiket (Workflow)',
          initiallyExpanded: true,
          children: [
            const StepTile(step: '1', title: 'Tiket Masuk', description: 'Setiap laporan baru akan muncul di Beranda dengan status "New". Notifikasi push juga akan dikirim ke staf yang relevan.'),
            const StepTile(step: '2', title: 'Penugasan (Assignment)', description: 'Tiket dapat ditugaskan ke staf spesifik. Anda bisa mengambil tiket untuk diri sendiri melalui tombol "Tugaskan ke Saya" di halaman detail.'),
            const StepTile(step: '3', title: 'Pengerjaan & Komunikasi', description: 'Gunakan fitur "Riwayat & Balas" untuk berkomunikasi dengan pelanggan dan mencatat progres. Lacak waktu kerja menggunakan fitur stopwatch.'),
            const StepTile(step: '4', title: 'Penyelesaian (Resolve)', description: 'Setelah masalah teratasi, ubah status tiket menjadi "Resolved". Tiket yang selesai akan otomatis berpindah ke tab "Riwayat".'),
          ],
        ),
        const DocumentationTile(
          icon: Icons.widgets_outlined,
          iconColor: Colors.orange,
          title: 'Panduan Fitur Utama',
          children: [
            FeatureDetail(
              title: '🔍 Pencarian & Filter',
              description: 'Gunakan kolom pencarian di bagian atas Beranda untuk mencari tiket berdasarkan Judul, ID, atau Nama Pelapor. Gunakan tombol filter (ikon corong) untuk menyaring tiket berdasarkan Kategori dan Prioritas.',
            ),
            FeatureDetail(
              title: '🔄 Urutkan Tiket (Sort)',
              description: 'Tekan tombol panah atas-bawah di samping filter untuk mengubah urutan tiket, baik berdasarkan tanggal pembaruan terakhir (terbaru) atau berdasarkan tingkat prioritas (kritis ke rendah).',
            ),
            FeatureDetail(
              title: '⏱️ Pelacak Waktu Kerja',
              description: 'Di halaman Detail Tiket, gunakan tombol putar/jeda pada bagian "Waktu Pengerjaan" untuk secara otomatis menghitung durasi penanganan tiket. Jangan lupa tekan tombol "Simpan Perubahan" setelah selesai.',
            ),
          ],
        ),
        DocumentationTile(
          icon: Icons.palette_outlined,
          iconColor: Colors.teal,
          title: 'Legenda & Indikator Visual',
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Prioritas Tiket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            // --- PERBAIKAN DI SINI: Menggunakan Image.asset ---
            LegendItem(
              leadingWidget: Image.asset('assets/images/label-critical.png'),
              label: 'Kritis (Critical): Harus segera ditangani.',
            ),
            LegendItem(
              leadingWidget: Image.asset('assets/images/label-high.png'),
              label: 'Tinggi (High): Memiliki urgensi tinggi.',
            ),
            LegendItem(
              leadingWidget: Image.asset('assets/images/label-medium.png'),
              label: 'Sedang (Medium): Prioritas standar.',
            ),
            LegendItem(
              leadingWidget: Image.asset('assets/images/label-low.png'),
              label: 'Rendah (Low): Tidak mendesak.',
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Status Tiket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const LegendItem(color: Color(0xFFD32F2F), label: 'New: Tiket baru, belum ada tindakan.'),
            const LegendItem(color: Color(0xFFE65100), label: 'Waiting Reply: Menunggu balasan dari pelanggan.'),
            const LegendItem(color: Color(0xFF1976D2), label: 'Replied: Anda sudah membalas, menunggu respons pelanggan.'),
            const LegendItem(color: Color(0xFF673AB7), label: 'In Progress: Tiket sedang dalam proses pengerjaan.'),
            const LegendItem(color: Color(0xFFC2185B), label: 'On Hold: Pengerjaan tiket ditunda sementara.'),
            const LegendItem(color: Color(0xFF388E3C), label: 'Resolved: Tiket sudah selesai dan ditutup.'),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Penugasan (Assignment)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const LegendItem(leadingWidget: Icon(Icons.person, color: Colors.blue), label: 'Tiket ditugaskan kepada Anda.'),
            const LegendItem(leadingWidget: Icon(Icons.group_outlined, color: Colors.grey), label: 'Tiket ditugaskan ke staf lain.'),
            const LegendItem(leadingWidget: Icon(Icons.person_add_disabled_outlined, color: Colors.grey), label: 'Tiket belum ditugaskan (Unassigned).'),
          ],
        ),
        const DocumentationTile(
          icon: Icons.lightbulb_outline,
          iconColor: Colors.amber,
          title: 'Tips & Praktik Terbaik',
          children: [
            FeatureDetail(
              title: 'Komunikasi Efektif',
              description: "Saat membalas pelanggan, gunakan bahasa yang jelas dan profesional. Setelah membalas, pastikan untuk mengubah status tiket ke 'Replied' atau 'Resolved' agar alur kerja tetap jelas.",
            ),
            FeatureDetail(
              title: "Kapan Menggunakan 'On Hold'",
              description: "Gunakan status 'On Hold' jika Anda menunggu informasi dari pihak ketiga (bukan pelanggan) atau jika pengerjaan tiket terpaksa ditunda. Ini membedakannya dari 'Waiting Reply' yang berarti menunggu balasan dari pelanggan.",
            ),
            FeatureDetail(
              title: 'Prioritaskan Pekerjaan Harian',
              description: "Awali hari Anda dengan menggunakan fitur 'Sort by Priority' untuk melihat tiket kritis terlebih dahulu. Ini memastikan isu yang paling mendesak ditangani lebih cepat.",
            ),
          ],
        ),
        const DocumentationTile(
          icon: Icons.book_outlined,
          iconColor: Colors.brown,
          title: 'Glosarium Istilah',
          children: [
            FaqItem(question: 'Tiket', answer: 'Catatan digital untuk setiap laporan, permintaan, atau masalah dari pengguna.'),
            FaqItem(question: 'Pelacak ID (Tracking ID)', answer: 'Kode unik untuk setiap tiket yang digunakan untuk melacak progresnya.'),
            FaqItem(question: 'Assignee', answer: 'Staf yang saat ini bertanggung jawab untuk menangani sebuah tiket.'),
            FaqItem(question: 'Status', answer: 'Tahapan tiket dalam siklus hidupnya (contoh: New, In Progress, Resolved).'),
            FaqItem(question: 'Prioritas', answer: 'Tingkat urgensi atau dampak dari sebuah tiket.'),
          ],
        ),
        const DocumentationTile(
            icon: Icons.quiz_outlined,
            iconColor: Colors.cyan,
            title: 'FAQ & Bantuan Aplikasi',
            children: [
              FaqItem(question: 'Mengapa saya tidak menerima notifikasi?', answer: 'Pastikan Anda telah memberikan izin notifikasi untuk aplikasi ini di pengaturan perangkat Anda. Cek juga koneksi internet Anda. Jika masih bermasalah, coba logout dan login kembali untuk me-refresh token notifikasi Anda.'),
              FaqItem(question: 'Bagaimana cara melihat tiket yang sudah selesai?', answer: 'Semua tiket yang berstatus "Resolved" akan otomatis dipindahkan ke tab "Riwayat" yang dapat diakses dari menu navigasi bawah.'),
              FaqItem(question: 'Bagaimana jika saya lupa password?', answer: 'Fitur reset password saat ini hanya tersedia di versi web HESK. Silakan akses HESK melalui browser untuk melakukan reset password.'),
              Divider(height: 24),
              FaqItem(question: 'Saya menemukan bug di aplikasi, harus lapor ke mana?', answer: 'Jika Anda menemukan masalah teknis pada aplikasi (crash, tombol tidak berfungsi, dll.), silakan laporkan langsung ke Tim Pengembang melalui [Email/Grup Pengembang].'),
            ],
          ),
      ],
    );
  }
}