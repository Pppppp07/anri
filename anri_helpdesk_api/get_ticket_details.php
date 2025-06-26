
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

$ticket_id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if (empty($ticket_id)) {
    echo json_encode(['success' => false, 'message' => 'ID Tiket tidak disediakan.']);
    exit();
}

$response = [
    'success' => false,
    'ticket' => null, // Kita akan isi ini
    'replies' => []
];

// 1. Ambil data tiket utama, TERMASUK history
$sql_ticket = "SELECT `history` FROM `hesk_tickets` WHERE `id` = ? LIMIT 1";
$stmt_ticket = mysqli_prepare($conn, $sql_ticket);
mysqli_stmt_bind_param($stmt_ticket, 'i', $ticket_id);
mysqli_stmt_execute($stmt_ticket);
$result_ticket = mysqli_stmt_get_result($stmt_ticket);
if ($ticket_data = mysqli_fetch_assoc($result_ticket)) {
    $response['ticket'] = $ticket_data;
}
mysqli_stmt_close($stmt_ticket);


// 2. Ambil data balasan (replies) - tidak berubah
$sql_replies = "SELECT `id`, `name`, `message`, `dt` FROM `hesk_replies` WHERE `replyto` = ? ORDER BY `dt` ASC";
$stmt_replies = mysqli_prepare($conn, $sql_replies);
mysqli_stmt_bind_param($stmt_replies, 'i', $ticket_id);
mysqli_stmt_execute($stmt_replies);
$result_replies = mysqli_stmt_get_result($stmt_replies);

$replies = [];
while ($row = mysqli_fetch_assoc($result_replies)) {
    $replies[] = $row;
}
$response['replies'] = $replies;
mysqli_stmt_close($stmt_replies);


$response['success'] = true;
echo json_encode($response);
mysqli_close($conn);
?>