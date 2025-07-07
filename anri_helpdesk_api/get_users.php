<?php
// Mulai output buffering untuk memastikan output JSON yang bersih
ob_start();

/**
 * Pengaturan error reporting sebaiknya diatur di file php.ini server.
 * Menghapusnya dari sini adalah praktik yang lebih aman untuk produksi.
 *
 * error_reporting(E_ALL);
 * ini_set('display_errors', 1);
 */

// AMANKAN ENDPOINT INI (Sudah Benar)
require 'auth_check.php';
require 'koneksi.php';

// --- HEADER CORS (Sudah Benar) ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Handle pre-flight request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_end_clean(); // Hentikan dan bersihkan buffer
    exit();
}
// --- AKHIR HEADER CORS ---

$response = ['success' => false, 'data' => [], 'message' => 'Gagal mengambil data pengguna.'];
$users = [];

try {
    // Fitur 1: Selalu tambahkan 'Unassigned' sebagai opsi pertama.
    $users[] = ['name' => 'Unassigned'];

    // Fitur 2: Ambil semua pengguna kecuali dengan ID 9999
    $sql = "SELECT `name` FROM `hesk_users` WHERE `id` != 9999 ORDER BY `name` ASC";
    $result = mysqli_query($conn, $sql);

    if ($result) {
        while ($row = mysqli_fetch_assoc($result)) {
            $users[] = $row;
        }
        $response['success'] = true;
        $response['data'] = $users;
        $response['message'] = 'Data pengguna berhasil diambil.';
    } else {
        // Ini tidak akan ditampilkan ke user karena error SQL akan ditangkap oleh catch block,
        // tapi baik untuk logika internal.
        throw new Exception(mysqli_error($conn));
    }
} catch (Exception $e) {
    // Jika terjadi error database atau lainnya
    $response['message'] = 'Terjadi kesalahan pada server: ' . $e->getMessage();
}


// --- BAGIAN AKHIR YANG DIPERBAIKI ---

// 1. Bersihkan semua output yang mungkin sudah ada (termasuk notice/warning PHP)
ob_clean();

// 2. Set header sebagai JSON
header('Content-Type: application/json');

// 3. Tutup koneksi database
mysqli_close($conn);

// 4. Cetak response sebagai JSON murni
echo json_encode($response);

// 5. Hentikan eksekusi skrip
exit();

?>