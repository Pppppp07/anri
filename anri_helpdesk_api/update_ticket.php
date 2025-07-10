<?php
// Selalu mulai output buffering sebagai "jaring pengaman"
ob_start();

// --- HEADER CORS UNTUK MENGIZINKAN AKSES DARI FLUTTER WEB ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Menangani Pre-flight Request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_end_flush(); 
    exit();
}

// Set header utama untuk semua respons
header('Content-Type: application/json');

// AMANKAN ENDPOINT INI
require 'auth_check.php';
require 'koneksi.php';

// Inisialisasi respons default
$response = ['success' => false, 'message' => 'Terjadi kesalahan yang tidak diketahui.'];

try {
    // 1. Menerima Data dari Aplikasi Flutter
    $ticket_id = isset($_POST['ticket_id']) ? (int)$_POST['ticket_id'] : 0;
    $status_text = isset($_POST['status']) ? trim($_POST['status']) : '';
    $priority_text = isset($_POST['priority']) ? trim($_POST['priority']) : '';
    $category_name = isset($_POST['category_name']) ? trim($_POST['category_name']) : '';
    $owner_name = isset($_POST['owner_name']) ? trim($_POST['owner_name']) : '';
    $time_worked = isset($_POST['time_worked']) ? trim($_POST['time_worked']) : '00:00:00';
    $due_date_str = isset($_POST['due_date']) ? trim($_POST['due_date']) : '';

    if (empty($ticket_id)) {
        throw new Exception('Ticket ID tidak boleh kosong.');
    }

    // 2. Mengubah Data Tekstual menjadi ID Sesuai Database
    $status_map = ['New' => 0, 'Waiting Reply' => 1, 'Replied' => 2, 'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5];
    $status_id = $status_map[$status_text] ?? 0;

    // --- PERBAIKAN FINAL LOGIKA PRIORITAS (SESUAI STANDAR HESK) ---
    // Ini adalah pemetaan yang paling benar dan seharusnya bekerja.
    $priority_map = [
        'Critical' => 1,
        'High'     => 2,
        'Medium'   => 3,
        'Low'      => 4,
    ];

    // Mengambil ID prioritas dari map. Jika teks tidak ditemukan, default ke 3 (Low).
    $priority_id = $priority_map[$priority_text] ?? 3;
    // --- AKHIR PERBAIKAN ---

    // Dapatkan ID kategori dari namanya
    $category_id = null;
    $stmt_cat = mysqli_prepare($conn, "SELECT id FROM `hesk_categories` WHERE `name` = ? LIMIT 1");
    mysqli_stmt_bind_param($stmt_cat, 's', $category_name);
    mysqli_stmt_execute($stmt_cat);
    $result_cat = mysqli_stmt_get_result($stmt_cat);
    if ($row_cat = mysqli_fetch_assoc($result_cat)) {
        $category_id = $row_cat['id'];
    }
    mysqli_stmt_close($stmt_cat);

    // Dapatkan ID owner (user) dari namanya
    $owner_id = 0; // Default ke 0 (Unassigned)
    if ($owner_name !== 'Unassigned' && !empty($owner_name)) {
        $stmt_user = mysqli_prepare($conn, "SELECT id FROM `hesk_users` WHERE `name` = ? LIMIT 1");
        mysqli_stmt_bind_param($stmt_user, 's', $owner_name);
        mysqli_stmt_execute($stmt_user);
        $result_user = mysqli_stmt_get_result($stmt_user);
        if ($row_user = mysqli_fetch_assoc($result_user)) {
            $owner_id = $row_user['id'];
        }
        mysqli_stmt_close($stmt_user);
    }
    
    // 3. Menangani Due Date yang Bisa Kosong
    $due_date_param = empty($due_date_str) ? NULL : $due_date_str;

    // 4. Menjalankan Query UPDATE dengan Aman
    $sql = "UPDATE `hesk_tickets` SET
                `status` = ?,
                `priority` = ?,
                `category` = ?,
                `owner` = ?,
                `time_worked` = ?,
                `due_date` = ?,
                `lastchange` = NOW()
            WHERE `id` = ?";

    $stmt = mysqli_prepare($conn, $sql);

    if ($stmt) {
        mysqli_stmt_bind_param($stmt, 'iiiissi', 
            $status_id, 
            $priority_id, 
            $category_id, 
            $owner_id, 
            $time_worked,
            $due_date_param,
            $ticket_id
        );

        if (mysqli_stmt_execute($stmt)) {
            $response['success'] = true;
            $response['message'] = 'Tiket berhasil diperbarui.';
        } else {
            throw new Exception('Gagal memperbarui tiket di database: ' . mysqli_stmt_error($stmt));
        }
        mysqli_stmt_close($stmt);
    } else {
        throw new Exception('Gagal mempersiapkan statement SQL: ' . mysqli_error($conn));
    }

} catch (Exception $e) {
    http_response_code(500);
    $response['success'] = false;
    $response['message'] = $e->getMessage();
}

// Bersihkan semua output yang mungkin sudah ada
ob_clean();

// Cetak response sebagai JSON murni
echo json_encode($response);

// Tutup koneksi database
mysqli_close($conn);

// Hentikan eksekusi skrip
exit();
?>