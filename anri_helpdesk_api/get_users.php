<?php
// --- HEADER CORS UNTUK MENGIZINKAN AKSES DARI FLUTTER WEB ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Menangani Pre-flight Request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
error_reporting(E_ALL);
ini_set('display_errors', 1);

// AMANKAN ENDPOINT INI
require 'auth_check.php';
require 'koneksi.php';

header('Content-Type: application/json');

// Variabel untuk menampung daftar pengguna
$users = [];

// Fitur 1: Selalu tambahkan 'Unassigned' sebagai opsi pertama.
// Diubah menjadi format objek/map agar sesuai dengan Flutter.
$users[] = ['name' => 'Unassigned'];

// Fitur 2: Ambil semua pengguna kecuali dengan ID 9999
$sql = "SELECT `name` FROM `hesk_users` WHERE `id` != 9999 ORDER BY `name` ASC";
$result = mysqli_query($conn, $sql);

if ($result) {
    while ($row = mysqli_fetch_assoc($result)) {
        // Setiap $row sudah dalam format ['name' => 'Nama Pengguna'].
        // Langsung tambahkan ke array $users.
        $users[] = $row;
    }
    echo json_encode(['success' => true, 'data' => $users]);
} else {
    // Kirim pesan error jika query gagal
    echo json_encode(['success' => false, 'message' => 'Gagal mengambil data pengguna.']);
}

mysqli_close($conn);

?>