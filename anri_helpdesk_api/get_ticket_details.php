<?php
// Mulai output buffering
ob_start();

// Hapus/comment error reporting untuk produksi
/*
error_reporting(E_ALL);
ini_set('display_errors', 1);
*/

// AMANKAN ENDPOINT INI
require 'auth_check.php';
require 'koneksi.php';

// --- HEADER CORS ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_end_clean();
    exit();
}
// --- AKHIR HEADER CORS ---

// Inisialisasi respons default
$response = [
    'success' => false,
    'ticket_details' => null,
    'replies' => [],
    'message' => 'ID Tiket tidak valid atau tidak ditemukan.'
];

$ticket_id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($ticket_id > 0) {
    try {
        // 1. Ambil data tiket utama
        $sql_ticket = "SELECT t.id, t.trackid, t.name AS requester_name, t.email AS requester_email, t.subject, t.message, t.dt AS creation_date, t.lastchange, t.status, t.priority, t.history, t.lastreplier, t.replies, t.time_worked, t.due_date, c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name, t.custom1, t.custom2, t.custom3, t.custom4, t.custom5 FROM `hesk_tickets` AS t LEFT JOIN `hesk_categories` AS c ON t.category = c.id LEFT JOIN `hesk_users` AS o ON t.owner = o.id LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id WHERE t.id = ? LIMIT 1";

        $stmt_ticket = mysqli_prepare($conn, $sql_ticket);
        mysqli_stmt_bind_param($stmt_ticket, 'i', $ticket_id);
        mysqli_stmt_execute($stmt_ticket);
        $result_ticket = mysqli_stmt_get_result($stmt_ticket);

        if ($ticket_details = mysqli_fetch_assoc($result_ticket)) {
            // Konversi tipe data jika perlu
            $ticket_details['id'] = (int)$ticket_details['id'];
            $ticket_details['replies'] = (int)$ticket_details['replies'];
            
            // Perbaikan untuk Owner & Last Replier
            $ticket_details['owner_name'] = $ticket_details['owner_name'] ?? 'Unassigned';
            $prefix = ($ticket_details['lastreplier'] == '1') ? 'Staf: ' : '';
            $ticket_details['last_replier_text'] = isset($ticket_details['last_replier_name']) ? $prefix . $ticket_details['last_replier_name'] : '-';

            // Konversi status & prioritas
            $status_map = ['New' => 0, 'Waiting Reply' => 1, 'Replied' => 2, 'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5];
            $ticket_details['status_text'] = array_search((int)$ticket_details['status'], $status_map, true) ?: 'Unknown';
            $ticket_details['priority_text'] = match ((int)$ticket_details['priority']) {
                0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low', default => 'Unknown',
            };

            $response['ticket_details'] = $ticket_details;

            // 2. Ambil data balasan (replies)
            $sql_replies = "SELECT `id`, `name`, `message`, `dt` FROM `hesk_replies` WHERE `replyto` = ? ORDER BY `dt` ASC";
            $stmt_replies = mysqli_prepare($conn, $sql_replies);
            mysqli_stmt_bind_param($stmt_replies, 'i', $ticket_id);
            mysqli_stmt_execute($stmt_replies);
            $result_replies = mysqli_stmt_get_result($stmt_replies);

            $replies = [];
            while ($row = mysqli_fetch_assoc($result_replies)) {
                $row['id'] = (int)$row['id'];
                $replies[] = $row;
            }
            $response['replies'] = $replies;
            mysqli_stmt_close($stmt_replies);

            $response['success'] = true;
            $response['message'] = 'Detail tiket berhasil diambil.';
        }
        mysqli_stmt_close($stmt_ticket);

    } catch (Exception $e) {
        $response['message'] = "Terjadi kesalahan pada server: " . $e->getMessage();
    }
}

// --- BAGIAN AKHIR ---
ob_clean();
header('Content-Type: application/json');
mysqli_close($conn);
echo json_encode($response);
exit();
?>