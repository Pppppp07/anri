<?php
/**
 * add_reply.php
 * VERSI BERSIH - Memanggil Pusat Notifikasi
 */

ob_start();

require 'koneksi.php';
require 'auth_check.php';
require 'notification_email.php'; // Panggil file notifikasi kita

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { http_response_code(200); exit(); }
header('Content-Type: application/json');

$response = ['success' => false, 'message' => 'Terjadi kesalahan.'];

try {
    // ... (Bagian mengambil data POST dan operasi database tetap sama) ...
    $ticket_id  = isset($_POST['ticket_id']) ? intval($_POST['ticket_id']) : 0;
    $message    = isset($_POST['message']) ? trim($_POST['message']) : '';
    $status_txt = isset($_POST['new_status']) ? trim($_POST['new_status']) : '';
    $staff_id   = isset($_POST['staff_id']) ? intval($_POST['staff_id']) : 1;
    $staff_name = isset($_POST['staff_name']) ? trim($_POST['staff_name']) : 'Administrator';

    if (!$ticket_id || empty($message) || empty($status_txt)) {
        throw new Exception('Data yang dikirim tidak lengkap.');
    }

    mysqli_begin_transaction($conn);

    $sql_reply = "INSERT INTO `hesk_replies` (`replyto`, `name`, `message`, `dt`, `staffid`) VALUES (?, ?, ?, NOW(), ?)";
    $stmt_reply = mysqli_prepare($conn, $sql_reply);
    mysqli_stmt_bind_param($stmt_reply, 'issi', $ticket_id, $staff_name, $message, $staff_id);
    mysqli_stmt_execute($stmt_reply);

    $status_map = ['New'=>0, 'Waiting Reply'=>1, 'Replied'=>2, 'Resolved'=>3, 'In Progress'=>4, 'On Hold'=>5];
    $new_status_id = $status_map[$status_txt];
    $sql_update = "UPDATE `hesk_tickets` SET `status`=?, `lastchange`=NOW(), `replies`=`replies`+1, `staffreplies`=`staffreplies`+1, `lastreplier`='1', `replierid`=? WHERE `id`=?";
    $stmt_update = mysqli_prepare($conn, $sql_update);
    mysqli_stmt_bind_param($stmt_update, 'iii', $new_status_id, $staff_id, $ticket_id);
    mysqli_stmt_execute($stmt_update);

    $sql_info = "SELECT `trackid`, `name` AS customer_name, `email` AS customer_email, `subject` FROM `hesk_tickets` WHERE `id` = ? LIMIT 1";
    $stmt_info = mysqli_prepare($conn, $sql_info);
    mysqli_stmt_bind_param($stmt_info, 'i', $ticket_id);
    mysqli_stmt_execute($stmt_info);
    $ticket_info = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_info));

    mysqli_commit($conn);

    // --- KIRIM NOTIFIKASI ---
    if ($ticket_info) {
        $hesk_url = rtrim($_ENV['HESK_URL'] ?? 'http://localhost/hesk', '/');
        $tracking_url = $hesk_url . '/ticket.php?track=' . $ticket_info['trackid'] . '&e=' . rawurlencode($ticket_info['customer_email']);

        $subject = ' [#' . $ticket_info['trackid'] .']'.'New reply to:' . $ticket_info['subject'];
        $body    = "<p>Dear " . htmlspecialchars($ticket_info['customer_name']) . ",</p>"
                 . "<p>We have just replied to your ticket \"" . htmlspecialchars($ticket_info['subject']) . "\".</p>"
                 . "<p>Isi balasan:<br>" . nl2br(htmlspecialchars($message)) . "</p>"
                 . "<p>To read the message, submit a reply and view details, please visit:<br>"
                 . "<a href=\"$tracking_url\">$tracking_url</a></p>"
                 . "<p>Sincerely,<br>Help Desk Mobile</p>";

        // Panggil fungsi dari pusat notifikasi
        send_notification_email($ticket_info['customer_email'], $ticket_info['customer_name'], $subject, $body);
    }
    
    $response = ['success' => true, 'message' => 'Balasan berhasil disimpan dan notifikasi sedang diproses.'];

} catch (Exception $e) {
    if ($conn) mysqli_rollback($conn);
    http_response_code(500);
    $response['message'] = 'Gagal memproses balasan: ' . $e->getMessage();
}

if ($conn) mysqli_close($conn);
ob_end_clean();
echo json_encode($response);
exit();
?>