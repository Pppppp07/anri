<?php
/**
 * File: update_fcm_token.php
 * Deskripsi: Endpoint untuk menerima dan menyimpan FCM token dari aplikasi Flutter ke database.
 */

// Sertakan CORS handler untuk konsistensi.
require 'cors_handler.php';

// Amankan endpoint ini. Hanya pengguna yang sudah login yang bisa memperbarui tokennya.
require 'auth_check.php'; 
require 'koneksi.php';

// Set header output sebagai JSON.
header('Content-Type: application/json');

// Dapatkan user_id dari token otentikasi yang sudah divalidasi oleh auth_check.php.
// Variabel $GLOBALS['current_user_id'] disediakan oleh auth_check.php
$user_id = $GLOBALS['current_user_id'] ?? 0;

// Ambil data JSON yang dikirim oleh aplikasi Flutter.
$data = json_decode(file_get_contents("php://input"));

// Ambil token dari data JSON, pastikan untuk membersihkannya dari spasi.
$fcm_token = isset($data->token) ? trim($data->token) : '';

// Validasi input
if (empty($fcm_token)) {
    http_response_code(400); // Bad Request
    echo json_encode(['success' => false, 'message' => 'FCM token tidak boleh kosong.']);
    exit();
}

if (empty($user_id)) {
    http_response_code(401); // Unauthorized
    echo json_encode(['success' => false, 'message' => 'Sesi tidak valid atau User ID tidak ditemukan.']);
    exit();
}

// Siapkan SQL statement untuk memperbarui token pengguna.
// Menggunakan prepared statement untuk mencegah SQL Injection.
$sql = "UPDATE `hesk_users` SET `fcm_token` = ? WHERE `id` = ?";
$stmt = mysqli_prepare($conn, $sql);

if ($stmt) {
    // Ikat parameter ke statement: 's' untuk string (token), 'i' untuk integer (user_id).
    mysqli_stmt_bind_param($stmt, 'si', $fcm_token, $user_id);

    // Eksekusi statement.
    if (mysqli_stmt_execute($stmt)) {
        // Jika berhasil, kirim response sukses.
        echo json_encode(['success' => true, 'message' => 'FCM Token berhasil diperbarui.']);
    } else {
        // Jika gagal, kirim response error server.
        http_response_code(500); // Internal Server Error
        echo json_encode(['success' => false, 'message' => 'Gagal memperbarui token di database: ' . mysqli_stmt_error($stmt)]);
    }
    // Tutup statement.
    mysqli_stmt_close($stmt);
} else {
    // Jika statement gagal disiapkan.
    http_response_code(500); // Internal Server Error
    echo json_encode(['success' => false, 'message' => 'Gagal mempersiapkan statement SQL: ' . mysqli_error($conn)]);
}

// Tutup koneksi database.
mysqli_close($conn);

?>