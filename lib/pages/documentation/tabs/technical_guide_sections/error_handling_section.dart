import 'package:flutter/material.dart';
import '../../widgets/content_widgets.dart';

class ErrorHandlingSection extends StatelessWidget {
  const ErrorHandlingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentationTile(
      icon: Icons.error_outline,
      iconColor: Colors.pink,
      title: 'Strategi Penanganan Error (Error Handling)',
      children: [
        FeatureDetail(
          title: 'Error API',
          description:
              'Setiap respons dari API memiliki kunci `success` (boolean). Jika `false`, aplikasi akan menampilkan pesan error yang dikirim dalam kunci `message` dari API menggunakan `SnackBar` atau dialog. Ini memastikan pesan error yang ditampilkan ke pengguna relevan dan informatif.',
        ),
        FeatureDetail(
          title: 'Error Konektivitas',
          description:
              'Sebelum melakukan panggilan API, aplikasi dapat memeriksa konektivitas jaringan. Jika tidak ada koneksi, panggilan API akan dibatalkan dan sebuah pesan "Tidak ada koneksi internet" akan ditampilkan kepada pengguna, biasanya melalui `SnackBar`.',
        ),
        FeatureDetail(
          title: 'Error Parsing Data',
          description:
              'Setiap proses parsing JSON dari respons API dibungkus dalam blok `try-catch`. Jika terjadi kegagalan (misalnya, format tidak sesuai dengan model Dart), aplikasi akan mencatat error tersebut (logging) dan menampilkan pesan error umum untuk mencegah aplikasi crash.',
        ),
      ],
    );
  }
}