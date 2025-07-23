<?php
/**
 * File: koneksi.php (Versi Final dengan Fungsi Logging)
 * Deskripsi: Mengatur koneksi dan menyediakan fungsi logging global.
 */

// 1. DEFINISIKAN FUNGSI LOGGING DI SINI, DI PALING ATAS
if (!function_exists('write_log')) {
    function write_log($log_msg) {
        $log_file = __DIR__ . '/_debug_log.txt';
        $timestamp = date('Y-m-d H:i:s');
        file_put_contents($log_file, "[$timestamp] " . $log_msg . PHP_EOL, FILE_APPEND);
    }
}

// 2. LANJUTKAN DENGAN SISA KODE KONEKSI
// Catatan: Kita tidak perlu `require 'vendor/autoload.php'` di sini,
// karena file ini akan dipanggil oleh auth_check.php yang sudah memuatnya.

// Muat variabel dari file .env
try {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
    $dotenv->load();
} catch (\Dotenv\Exception\InvalidPathException $e) {
    // Gunakan fungsi logging kita jika Dotenv gagal
    write_log("FATAL ERROR: File .env tidak ditemukan.");
    http_response_code(500);
    die(json_encode(['success' => false, 'message' => 'File .env tidak ditemukan. Pastikan file .env ada di direktori root.']));
}

// Ambil kredensial dari environment variable ($_ENV)
$db_host = $_ENV['DB_HOST'] ?? null;
$db_user = $_ENV['DB_USER'] ?? null;
$db_pass = $_ENV['DB_PASS'] ?? null;
$db_name = $_ENV['DB_NAME'] ?? null;

// Validasi apakah variabel berhasil dimuat
if (!$db_host || !$db_name || !$db_user) {
    write_log("FATAL ERROR: Konfigurasi database tidak lengkap atau tidak ditemukan di .env");
    http_response_code(500);
    die(json_encode(['success' => false, 'message' => 'Konfigurasi database tidak lengkap atau tidak ditemukan.']));
}

// Buat koneksi ke database
$conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);

// Cek koneksi
if (!$conn) {
  write_log("FATAL ERROR: Koneksi ke database gagal: " . mysqli_connect_error());
  http_response_code(500);
  die(json_encode(['success' => false, 'message' => 'Koneksi ke database gagal.']));
}

// Set karakter set ke utf8mb4 untuk mendukung karakter unicode
mysqli_set_charset($conn, "utf8mb4");

?>