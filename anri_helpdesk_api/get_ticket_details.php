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

header('Content-Type: application/json');

// Mengambil ID tiket dari parameter URL
$ticket_id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if (empty($ticket_id)) {
    echo json_encode(['success' => false, 'message' => 'ID Tiket tidak disediakan.']);
    exit();
}

$response = [
    'success' => false,
    'ticket_details' => null,
    'replies' => []
];

// 1. Ambil data tiket utama dengan SEMUA JOIN yang diperlukan
$sql_ticket = "SELECT
                    t.id, t.trackid, t.name AS requester_name, t.email AS requester_email,
                    t.subject, t.message, t.dt AS creation_date, t.lastchange,
                    t.status, t.priority, t.history, t.lastreplier, t.replies, t.time_worked, t.due_date,
                    c.name AS category_name,
                    o.name AS owner_name,
                    lr.name AS last_replier_name,
                    t.custom1, t.custom2, t.custom3, t.custom4, t.custom5
                FROM `hesk_tickets` AS t
                LEFT JOIN `hesk_categories` AS c ON t.category = c.id
                LEFT JOIN `hesk_users` AS o ON t.owner = o.id
                LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id
                WHERE t.id = ? LIMIT 1";

$stmt_ticket = mysqli_prepare($conn, $sql_ticket);
mysqli_stmt_bind_param($stmt_ticket, 'i', $ticket_id);
mysqli_stmt_execute($stmt_ticket);
$result_ticket = mysqli_stmt_get_result($stmt_ticket);

if ($ticket_details = mysqli_fetch_assoc($result_ticket)) {
    // --- Perbaikan untuk Owner yang kosong ---
    if (is_null($ticket_details['owner_name'])) {
        $ticket_details['owner_name'] = 'Unassigned';
    }

    // --- Perbaikan untuk Pembalas Terakhir yang kosong ---
    if (is_null($ticket_details['last_replier_name'])) {
        $ticket_details['last_replier_text'] = '-';
    } else {
        $prefix = ($ticket_details['lastreplier'] == '1') ? 'Staf: ' : '';
        $ticket_details['last_replier_text'] = $prefix . $ticket_details['last_replier_name'];
    }

    // Menyesuaikan kode status dan prioritas menjadi teks
    $status_map = [
        'New' => 0, 'Waiting Reply' => 1, 'Replied' => 2,
        'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5,
    ];
    $ticket_details['status_text'] = array_search((int)$ticket_details['status'], $status_map, true) ?: 'Unknown';
    $ticket_details['priority_text'] = match ((int)$ticket_details['priority']) {
        0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low', default => 'Unknown',
    };

    $response['ticket_details'] = $ticket_details;
    $response['success'] = true; 
}
mysqli_stmt_close($stmt_ticket);

// 2. Ambil data balasan (replies), hanya jika tiket ditemukan
if ($response['success']) {
    $sql_replies = "SELECT `id`, `name`, `message`, `dt` AS reply_date FROM `hesk_replies` WHERE `replyto` = ? ORDER BY `dt` ASC";
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
}

echo json_encode($response);
mysqli_close($conn);
?>