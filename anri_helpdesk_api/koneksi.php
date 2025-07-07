<?php
// --- HEADER CORS UNTUK MENGIZINKAN AKSES DARI FLUTTER WEB ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// 1. Sertakan autoloader Composer
require_once __DIR__ . '/vendor/autoload.php';

// 2. Muat variabel dari file .env
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// 3. Ambil kredensial dari environment variable ($_ENV)
$db_host = $_ENV['DB_HOST'];
$db_user = $_ENV['DB_USER'];
$db_pass = $_ENV['DB_PASS'];
$db_name = $_ENV['DB_NAME'];

// Validasi apakah variabel berhasil dimuat
if (!$db_host || !$db_name || !$db_user) {
    http_response_code(500);
    die(json_encode(['success' => false, 'message' => 'Konfigurasi database tidak ditemukan.']));
}

// Buat koneksi ke database (kode setelah ini tidak berubah)
$conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);

// Cek koneksi
if (!$conn) {
  // Jika koneksi gagal, hentikan skrip dan tampilkan pesan error
  die("Koneksi gagal: " . mysqli_connect_error());
}

// Set karakter set ke utf8mb4 untuk mendukung karakter unicode
mysqli_set_charset($conn, "utf8mb4");
?>