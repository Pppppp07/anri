import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class ApiEndpointsSection extends StatelessWidget {
  const ApiEndpointsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.http_outlined,
      iconColor: Colors.orange,
      title: 'Dokumentasi API Endpoint',
      children: [
        ApiEndpointCard(
          method: 'POST',
          endpoint: '/login.php',
          description:
              'Mengautentikasi kredensial pengguna dan mengembalikan data pengguna serta token sesi jika berhasil.',
          requestBody:
              '{\n  "user": "nama_pengguna",\n  "pass": "kata_sandi",\n  "remember_me": true\n}',
          responseBody:
              '{\n  "success": true,\n  "data": {...user_data},\n  "token": "selector:validator"\n}',
        ),
        ApiEndpointCard(
          method: 'GET',
          endpoint: '/get_app_data.php',
          description:
              'Mengambil data master yang dibutuhkan aplikasi saat startup, seperti daftar kategori, semua staf, dan status tiket.',
          responseBody:
              '{\n  "success": true,\n  "categories": [...],\n  "staff": [...],\n  "statuses": [...]\n}',
        ),
        ApiEndpointCard(
          method: 'GET',
          endpoint: '/get_tickets.php',
          description:
              'Mengambil daftar tiket berdasarkan filter (misal: semua tiket, tiket saya). Memerlukan token otentikasi.',
          responseBody:
              '{\n  "success": true,\n  "data": [ ...list_of_tickets ]\n}',
        ),
        ApiEndpointCard(
          method: 'GET',
          endpoint: '/get_ticket_details.php',
          description:
              'Mengambil detail lengkap sebuah tiket, termasuk riwayat balasan. Memerlukan `id` tiket sebagai parameter.',
          responseBody:
              '{\n  "success": true,\n  "ticket_details": {...},\n  "replies": [...]\n}',
        ),
        ApiEndpointCard(
          method: 'POST',
          endpoint: '/add_reply.php',
          description:
              'Mengirim balasan baru ke sebuah tiket. Memerlukan token, ID tiket, dan isi pesan.',
          requestBody:
              '{\n  "ticket_id": 123,\n  "message": "Ini adalah balasan dari staf."\n}',
          responseBody:
              '{\n  "success": true,\n  "message": "Balasan berhasil dikirim."\n}',
        ),
        ApiEndpointCard(
          method: 'POST',
          endpoint: '/update_ticket_details.php',
          description:
              'Memperbarui atribut spesifik dari sebuah tiket, seperti status, prioritas, atau pemilik (assignee).',
          requestBody:
              '{\n  "ticket_id": 123,\n  "new_status": "3",\n  "new_owner": "5",\n  "new_priority": "1"\n}',
          responseBody:
              '{\n  "success": true,\n  "message": "Tiket berhasil diperbarui."\n}',
        ),
        ApiEndpointCard(
          method: 'CONTOH ERROR',
          endpoint: '/get_tickets.php',
          description:
              'Contoh respons ketika terjadi error, misalnya token tidak valid atau parameter hilang.',
          responseBody:
              '{\n  "success": false,\n  "message": "Autentikasi gagal: Token tidak valid atau kedaluwarsa."\n}',
          isError: true,
        ),
      ],
    );
  }
}