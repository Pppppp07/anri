<?php
// Perbaikan Lengkap untuk login.php

// 1. Mulai output buffering untuk menangkap semua output.
// Ini mencegah "notice" atau "warning" PHP merusak output JSON.
ob_start();

/**
 * Pengaturan error reporting sebaiknya diatur di file php.ini pada server Anda, bukan di dalam skrip.
 * Untuk lingkungan produksi, atur: display_errors = Off dan log_errors = On.
 * Baris di bawah ini sengaja dihapus atau di-comment agar lebih aman.
 *
 * error_reporting(E_ALL);
 * ini_set('display_errors', 1);
 */

// 2. Muat koneksi yang sudah menggunakan .env untuk kredensial.
// Pastikan file 'koneksi.php' Anda sudah diperbaiki sesuai panduan sebelumnya.
require 'koneksi.php';

// --- HEADER CORS (Sudah Benar) ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Handle pre-flight request (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_end_clean(); // Bersihkan buffer dan hentikan skrip
    exit();
}
// --- AKHIR HEADER CORS ---

// Inisialisasi array response default
$response = ['success' => false, 'message' => 'Terjadi kesalahan yang tidak diketahui.'];

// Ambil data JSON dari body request
$data = json_decode(file_get_contents("php://input"));

// Pastikan data yang diterima tidak kosong dan merupakan objek yang valid
if (is_object($data) && isset($data->username) && isset($data->password)) {
    $username = $data->username;
    $password = $data->password;

    // Gunakan prepared statement untuk keamanan (sudah benar)
    $sql = "SELECT id, `user`, `pass`, `name`, `email` FROM `hesk_users` WHERE `user` = ?";
    $stmt = mysqli_prepare($conn, $sql);

    if ($stmt) {
        mysqli_stmt_bind_param($stmt, "s", $username);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);

        if (mysqli_num_rows($result) > 0) {
            $row = mysqli_fetch_assoc($result);

            // Verifikasi password (sudah benar)
            if (password_verify($password, $row['pass'])) {
                try {
                    $user_id = $row['id'];

                    // Logika pembuatan token (sudah benar)
                    $selector = bin2hex(random_bytes(6));
                    $validator = bin2hex(random_bytes(32));
                    $hashed_validator = hash('sha256', $validator);
                    $expires = date('Y-m-d H:i:s', time() + (30 * 24 * 60 * 60)); // 30 hari

                    // Gunakan transaksi untuk memastikan konsistensi data (sudah benar)
                    mysqli_begin_transaction($conn);

                    // Hapus token lama
                    $delete_old_sql = "DELETE FROM `hesk_auth_tokens` WHERE `user_id` = ?";
                    $stmt_delete = mysqli_prepare($conn, $delete_old_sql);
                    mysqli_stmt_bind_param($stmt_delete, "i", $user_id);
                    mysqli_stmt_execute($stmt_delete);
                    mysqli_stmt_close($stmt_delete);

                    // Masukkan token baru
                    $sql_token = "INSERT INTO `hesk_auth_tokens` (`selector`, `token`, `user_id`, `expires`) VALUES (?, ?, ?, ?)";
                    $stmt_token = mysqli_prepare($conn, $sql_token);
                    mysqli_stmt_bind_param($stmt_token, "ssis", $selector, $hashed_validator, $user_id, $expires);

                    if (!mysqli_stmt_execute($stmt_token)) {
                        throw new Exception('Gagal menyimpan sesi token: ' . mysqli_stmt_error($stmt_token));
                    }
                    mysqli_stmt_close($stmt_token);

                    mysqli_commit($conn);

                    // Siapkan response sukses
                    $response['success'] = true;
                    $response['message'] = "Login berhasil!";
                    $response['user_data'] = [
                        'id' => (int)$row['id'],
                        'name' => $row['name'],
                        'email' => $row['email'],
                        'username' => $row['user']
                    ];
                    $response['token'] = $selector . ':' . $validator;

                } catch (Exception $e) {
                    mysqli_rollback($conn);
                    $response['message'] = "Kesalahan pada server: " . $e->getMessage();
                }
            } else {
                $response['message'] = "Username atau password salah.";
            }
        } else {
            $response['message'] = "Username tidak ditemukan.";
        }
        mysqli_stmt_close($stmt);
    } else {
        $response['message'] = 'Gagal mempersiapkan statement SQL: ' . mysqli_error($conn);
    }
} else {
    $response['message'] = "Data tidak lengkap. Pastikan username dan password dikirim.";
}

// --- BAGIAN AKHIR YANG DIPERBAIKI ---

// 3. Bersihkan semua output yang mungkin sudah ada (termasuk notice/warning PHP)
ob_clean();

// 4. Set header sebagai JSON
header('Content-Type: application/json');

// 5. Tutup koneksi database
mysqli_close($conn);

// 6. Cetak response sebagai JSON murni
echo json_encode($response);

// 7. Hentikan eksekusi skrip
exit();
?>