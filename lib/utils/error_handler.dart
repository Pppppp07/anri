// lib/utils/error_handler.dart

class ErrorIdentifier {
  final String referenceCode;
  final String userMessage;

  ErrorIdentifier({required this.referenceCode, required this.userMessage});

  /// Menganalisis pesan error mentah dan mengembalikannya dalam format yang aman.
  /// Hanya untuk penggunaan lokal.
  static ErrorIdentifier from(String rawError) {
    String typeCode;
    String friendlyMessage;

    final lowerCaseError = rawError.toLowerCase();

    if (lowerCaseError.contains('socketexception') ||
        lowerCaseError.contains('failed host lookup')) {
      typeCode = 'NET';
      friendlyMessage =
          'Tidak dapat terhubung ke server. Mohon periksa koneksi internet Anda.';
    } else if (lowerCaseError.contains('timeoutexception')) {
      typeCode = 'TIMEOUT';
      friendlyMessage = 'Koneksi ke server memakan waktu terlalu lama.';
    } else if (lowerCaseError.contains('formatexception')) {
      typeCode = 'PARSE';
      friendlyMessage = 'Terjadi kesalahan saat memproses data dari server.';
    } else if (lowerCaseError.contains('sesi tidak valid')) {
      typeCode = 'AUTH';
      friendlyMessage =
          'Sesi Anda telah berakhir. Silakan login kembali untuk melanjutkan.';
    } else {
      typeCode = 'UNKNOWN';
      friendlyMessage =
          'Terjadi kesalahan yang tidak terduga. Silakan coba lagi nanti.';
    }

    // Buat ID unik berdasarkan waktu
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);

    final referenceCode = 'REF-$typeCode-$timestamp';

    // Cetak ke konsol debug untuk developer saat pengembangan
    print('LOCAL ERROR TRACE | Code: $referenceCode | Raw Error: $rawError');

    return ErrorIdentifier(
      referenceCode: referenceCode,
      userMessage: friendlyMessage,
    );
  }
}