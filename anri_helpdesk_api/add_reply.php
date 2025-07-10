<?php
// Mulai output buffering untuk menangkap semua kemungkinan output liar
ob_start();

// --- HEADER CORS UNTUK MENGIZINKAN AKSES DARI FLUTTER WEB ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Menangani Pre-flight Request (penting untuk browser)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_end_flush();
    exit();
}

// HAPUS BARIS INI: Atur error reporting di php.ini, bukan di skrip API
// error_reporting(E_ALL);
// ini_set('display_errors', 1);

// AMANKAN ENDPOINT INI
require 'auth_check.php';

// Sertakan file koneksi database
require 'koneksi.php';

// Atur header default sebagai JSON
header('Content-Type: application/json');
$response = ['success' => false, 'message' => 'Terjadi kesalahan yang tidak diketahui.'];

try {
    // Mengambil data dari request POST
    $ticket_id = isset($_POST['ticket_id']) ? (int)$_POST['ticket_id'] : 0;
    $message = isset($_POST['message']) ? trim($_POST['message']) : '';
    $new_status_text = isset($_POST['new_status']) ? trim($_POST['new_status']) : '';
    $staff_id = isset($_POST['staff_id']) ? (int)$_POST['staff_id'] : 1;
    $staff_name = isset($_POST['staff_name']) ? trim($_POST['staff_name']) : 'Administrator';

    // Validasi input
    if (empty($ticket_id) || empty($message) || empty($new_status_text)) {
        throw new Exception('Data tidak lengkap.');
    }

    $status_map = [
        'New' => 0, 'Waiting Reply' => 1, 'Replied' => 2,
        'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5,
    ];

    if (!array_key_exists($new_status_text, $status_map)) {
        throw new Exception('Status tidak valid.');
    }

    $new_status_id = $status_map[$new_status_text];

    // Memulai transaction
    mysqli_begin_transaction($conn);

    // 1. Masukkan balasan ke tabel hesk_replies
    $sql_reply = "INSERT INTO `hesk_replies` (`replyto`, `name`, `message`,`message_html`, `dt`, `staffid`) VALUES (?, ?, ?, ?, NOW(), ?)";
    $stmt_reply = mysqli_prepare($conn, $sql_reply);
    mysqli_stmt_bind_param($stmt_reply, 'isssi', $ticket_id, $staff_name, $message,$message, $staff_id);
    if (!mysqli_stmt_execute($stmt_reply)) {
        throw new Exception("Gagal menyimpan balasan: " . mysqli_stmt_error($stmt_reply));
    }
    mysqli_stmt_close($stmt_reply);

    // 2. Update tiket di tabel hesk_tickets
    $sql_ticket = "UPDATE `hesk_tickets` SET 
                    `status` = ?, 
                    `lastchange` = NOW(), 
                    `replies` = `replies` + 1, 
                    `staffreplies` = `staffreplies` + 1,
                    `lastreplier` = '1', 
                    `replierid` = ?
                   WHERE `id` = ?";
    $stmt_ticket = mysqli_prepare($conn, $sql_ticket);
    mysqli_stmt_bind_param($stmt_ticket, 'iii', $new_status_id, $staff_id, $ticket_id);
    if (!mysqli_stmt_execute($stmt_ticket)) {
        throw new Exception("Gagal memperbarui tiket: " . mysqli_stmt_error($stmt_ticket));
    }
    mysqli_stmt_close($stmt_ticket);

    // Jika semua berhasil, commit transaction
    mysqli_commit($conn);

    $response['success'] = true;
    $response['message'] = 'Balasan berhasil dikirim.';

} catch (Exception $e) {
    // Jika ada error di mana pun, batalkan semua perubahan
    mysqli_rollback($conn);
    http_response_code(500); // Set kode error server
    $response['success'] = false;
    $response['message'] = 'Gagal memproses balasan: ' . $e->getMessage();
}

// --- BAGIAN AKHIR YANG DIPERBAIKI ---

// 1. Bersihkan semua output yang mungkin sudah ada (termasuk notice/warning PHP)
ob_clean();

// 2. Cetak response sebagai JSON murni
echo json_encode($response);

// 3. Tutup koneksi database
mysqli_close($conn);

// 4. Hentikan eksekusi skrip
exit();
?>