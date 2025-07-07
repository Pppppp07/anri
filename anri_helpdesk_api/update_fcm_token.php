<?php
// anri_helpdesk_api/update_fcm_token.php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

require 'auth_check.php'; // Memastikan user sudah login dan valid
require 'koneksi.php';

// Mendapatkan user_id dari token otentikasi yang sudah divalidasi oleh auth_check.php
$user_id = $auth_token_row['user_id']; 

$data = json_decode(file_get_contents("php://input"));
$fcm_token = isset($data->token) ? trim($data->token) : '';

if (empty($fcm_token)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'FCM token tidak boleh kosong.']);
    exit();
}

if (empty($user_id)) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'User ID tidak ditemukan dari sesi otentikasi.']);
    exit();
}

$sql = "UPDATE `hesk_users` SET `fcm_token` = ? WHERE `id` = ?";
$stmt = mysqli_prepare($conn, $sql);

if ($stmt) {
    mysqli_stmt_bind_param($stmt, 'si', $fcm_token, $user_id);
    if (mysqli_stmt_execute($stmt)) {
        echo json_encode(['success' => true, 'message' => 'FCM Token berhasil diperbarui.']);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal memperbarui token: ' . mysqli_stmt_error($stmt)]);
    }
    mysqli_stmt_close($stmt);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Gagal mempersiapkan statement SQL: ' . mysqli_error($conn)]);
}

mysqli_close($conn);
?>