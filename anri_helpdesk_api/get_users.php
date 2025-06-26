<?php
// --- HEADER CORS UNTUK MENGIZINKAN AKSES DARI FLUTTER WEB ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Menangani Pre-flight Request (penting untuk browser)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
error_reporting(E_ALL);
ini_set('display_errors', 1);


// AMANKAN ENDPOINT INI
require 'auth_check.php';
require 'koneksi.php';

header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

$users = [];
// Ambil semua pengguna yang bukan admin dengan ID 9999 (jika ada)
$sql = "SELECT `name` FROM `hesk_users` WHERE `id` != 9999 ORDER BY `name` ASC";
$result = mysqli_query($conn, $sql);

if ($result) {
    // Selalu tambahkan 'Unassigned' sebagai opsi pertama
    $users[] = 'Unassigned';
    while ($row = mysqli_fetch_assoc($result)) {
        $users[] = $row['name'];
    }
    echo json_encode(['success' => true, 'data' => $users]);
} else {
    echo json_encode(['success' => false, 'message' => 'Gagal mengambil data pengguna.']);
}

mysqli_close($conn);
?>