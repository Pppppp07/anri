import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class SecurityGuideSection extends StatelessWidget {
  const SecurityGuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.security_outlined,
      iconColor: Colors.red,
      title: 'Panduan Keamanan',
      children: [
        FeatureDetail(
          title: 'Otentikasi Berbasis Token (Bearer Token)',
          description:
              'Setiap endpoint API (kecuali login) dilindungi. Klien (aplikasi Flutter) harus menyertakan header `Authorization: Bearer <TOKEN>` pada setiap permintaan. Token ini didapat saat login berhasil dan disimpan secara aman di perangkat.',
        ),
        FeatureDetail(
          title: 'Mekanisme Token "Remember Me" (Selector:Validator)',
          description:
              'Untuk menjaga sesi login, kami menggunakan teknik "Selector:Validator" yang aman. Saat login, sepasang token (selector dan validator) dibuat dan disimpan di tabel `hesk_auth_tokens`. Validator di-hash. Klien menyimpan selector dan validator mentah di `shared_preferences`. Saat verifikasi, klien mengirim keduanya. Backend mencari selector, me-hash validator yang dikirim, dan membandingkannya dengan hash di database untuk mencegah serangan timing attack.',
        ),
        FeatureDetail(
          title: 'Pencegahan SQL Injection',
          description:
              'Semua query database di sisi backend PHP menggunakan Prepared Statements dengan parameter binding (menggunakan `mysqli`). Ini adalah standar industri untuk mencegah serangan injeksi SQL dengan memastikan input dari pengguna tidak bisa dieksekusi sebagai kode SQL.',
        ),
        FeatureDetail(
          title: 'Konfigurasi Sensitif',
          description:
              'Kredensial database, kunci API (FCM, Telegram), dan konfigurasi sensitif lainnya disimpan di file `.env` di Flutter dan di file `anri_config.inc.php` yang berada di luar direktori web root pada backend. Ini mencegah akses langsung ke file konfigurasi dari browser atau pihak luar.',
        ),
      ],
    );
  }
}