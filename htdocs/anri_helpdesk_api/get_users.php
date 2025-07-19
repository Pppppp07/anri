<?php
// --- HEADER WAJIB UNTUK SEMUA ENDPOINT YANG BUTUH LOGIN ---
require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/cors_handler.php';
ob_start();

// Panggil auth_check.php. File ini sudah memanggil koneksi.php (yang berisi write_log).
require_once __DIR__ . '/auth_check.php';
// --- AKHIR HEADER WAJIB ---

$response = ['success' => false, 'data' => [], 'message' => 'Gagal mengambil data pengguna.'];
$users = [];

try {
    // Fitur 1: Selalu tambahkan 'Unassigned' sebagai opsi pertama.
    $users[] = ['name' => 'Unassigned'];

    // --- PERBAIKAN: Hapus kondisi `AND name != 'admin'` ---
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