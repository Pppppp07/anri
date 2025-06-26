<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);


// AMANKAN ENDPOINT INI
require 'auth_check.php';

// Sertakan file koneksi database
require 'koneksi.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

// Mengambil data dari request POST
$ticket_id = isset($_POST['ticket_id']) ? (int)$_POST['ticket_id'] : 0;
$message = isset($_POST['message']) ? trim($_POST['message']) : '';
$new_status_text = isset($_POST['new_status']) ? trim($_POST['new_status']) : '';
$staff_id = isset($_POST['staff_id']) ? (int)$_POST['staff_id'] : 1; // Asumsi ID Staf adalah 1 (Administrator), sesuaikan jika perlu
$staff_name = isset($_POST['staff_name']) ? trim($_POST['staff_name']) : 'Administrator'; // Nama staf untuk balasan

// Validasi input
if (empty($ticket_id) || empty($message) || empty($new_status_text)) {
    echo json_encode(['success' => false, 'message' => 'Data tidak lengkap.']);
    exit();
}

$status_map = [
    'New' => 0, 'Waiting Reply' => 1, 'Replied' => 2,
    'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5,
];

if (!array_key_exists($new_status_text, $status_map)) {
    echo json_encode(['success' => false, 'message' => 'Status tidak valid.']);
    exit();
}

$new_status_id = $status_map[$new_status_text];

// Memulai transaction
mysqli_begin_transaction($conn);

try {
    // 1. Masukkan balasan ke tabel hesk_replies
    $sql_reply = "INSERT INTO `hesk_replies` (`replyto`, `name`, `message`, `dt`, `staffid`) VALUES (?, ?, ?, NOW(), ?)";
    $stmt_reply = mysqli_prepare($conn, $sql_reply);
    mysqli_stmt_bind_param($stmt_reply, 'issi', $ticket_id, $staff_name, $message, $staff_id);
    mysqli_stmt_execute($stmt_reply);
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
    mysqli_stmt_execute($stmt_ticket);
    mysqli_stmt_close($stmt_ticket);

    // Jika semua berhasil, commit transaction
    mysqli_commit($conn);

    echo json_encode(['success' => true, 'message' => 'Balasan berhasil dikirim.']);

} catch (mysqli_sql_exception $exception) {
    // Jika ada error, rollback semua perubahan
    mysqli_rollback($conn);
    echo json_encode(['success' => false, 'message' => 'Gagal memproses balasan: ' . $exception->getMessage()]);
}

mysqli_close($conn);
?>