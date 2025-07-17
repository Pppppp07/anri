<?php
/**
 * update_ticket.php
 * VERSI FINAL - Dengan Logika Prioritas yang Benar dan Notifikasi Status (dengan Link)
 */

ob_start();

require 'vendor/autoload.php';
require 'koneksi.php';
require 'auth_check.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { http_response_code(200); exit(); }
header('Content-Type: application/json');

$response = ['success' => false, 'message' => 'Terjadi kesalahan.'];

try {
    $ticket_id     = isset($_POST['ticket_id']) ? (int)$_POST['ticket_id'] : 0;
    $status_text   = isset($_POST['status']) ? trim($_POST['status']) : '';
    $priority_text = isset($_POST['priority']) ? trim($_POST['priority']) : '';
    $category_name = isset($_POST['category_name']) ? trim($_POST['category_name']) : '';
    $owner_name    = isset($_POST['owner_name']) ? trim($_POST['owner_name']) : '';
    $time_worked   = isset($_POST['time_worked']) ? trim($_POST['time_worked']) : '00:00:00';
    $due_date_str  = isset($_POST['due_date']) ? trim($_POST['due_date']) : '';

    if (empty($ticket_id)) {
        throw new Exception('Ticket ID tidak boleh kosong.');
    }

    $sql_old_info = "SELECT `status`, `trackid`, `name` AS customer_name, `email` AS customer_email, `subject` FROM `hesk_tickets` WHERE `id` = ? LIMIT 1";
    $stmt_old = mysqli_prepare($conn, $sql_old_info);
    mysqli_stmt_bind_param($stmt_old, 'i', $ticket_id);
    mysqli_stmt_execute($stmt_old);
    $ticket_info = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_old));
    
    $status_map = ['New'=>0, 'Waiting Reply'=>1, 'Replied'=>2, 'Resolved'=>3, 'In Progress'=>4, 'On Hold'=>5];
    $old_status_id = $ticket_info ? $ticket_info['status'] : -1;
    $new_status_id = $status_map[$status_text] ?? $old_status_id;
    $status_changed = ($old_status_id != $new_status_id);

    $priority_map = ['Critical' => 0, 'High' => 1, 'Medium' => 2, 'Low' => 3];
    $priority_id = $priority_map[$priority_text] ?? 3;

    mysqli_begin_transaction($conn);
    
    $category_id = null;
    $stmt_cat = mysqli_prepare($conn, "SELECT id FROM `hesk_categories` WHERE `name` = ? LIMIT 1");
    mysqli_stmt_bind_param($stmt_cat, 's', $category_name);
    mysqli_stmt_execute($stmt_cat);
    if ($row_cat = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_cat))) $category_id = $row_cat['id'];
    
    $owner_id = 0;
    if ($owner_name !== 'Unassigned' && !empty($owner_name)) {
        $stmt_user = mysqli_prepare($conn, "SELECT id FROM `hesk_users` WHERE `name` = ? LIMIT 1");
        mysqli_stmt_bind_param($stmt_user, 's', $owner_name);
        mysqli_stmt_execute($stmt_user);
        if ($row_user = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_user))) $owner_id = $row_user['id'];
    }
    
    $due_date_param = empty($due_date_str) ? NULL : $due_date_str;

    $sql_update = "UPDATE `hesk_tickets` SET `status`=?, `priority`=?, `category`=?, `owner`=?, `time_worked`=?, `due_date`=?, `lastchange`=NOW() WHERE `id`=?";
    $stmt_update = mysqli_prepare($conn, $sql_update);
    mysqli_stmt_bind_param($stmt_update, 'iiiissi', $new_status_id, $priority_id, $category_id, $owner_id, $time_worked, $due_date_param, $ticket_id);
    mysqli_stmt_execute($stmt_update);

    mysqli_commit($conn);

    if ($status_changed && $ticket_info) {
        $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
        $dotenv->load();

        $mail = new PHPMailer(true);
        try {
            $mail->isSMTP();
            $mail->Host       = $_ENV['SMTP_HOST'];
            $mail->SMTPAuth   = true;
            $mail->Username   = $_ENV['SMTP_USER'];
            $mail->Password   = $_ENV['SMTP_PASS'];
            if (strtolower($_ENV['SMTP_ENCRYPTION']) == 'ssl') $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
            elseif (strtolower($_ENV['SMTP_ENCRYPTION']) == 'tls') $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port       = $_ENV['SMTP_PORT'];
            $mail->CharSet    = 'UTF-8';

            $mail->setFrom($_ENV['SMTP_USER'], 'Help Desk Mobile');
            $mail->addAddress($ticket_info['customer_email'], $ticket_info['customer_name']);

            // --- PERUBAHAN UTAMA DI SINI ---
            $hesk_url = rtrim($_ENV['HESK_URL'] ?? 'http://localhost/hesk', '/');
            $tracking_url = $hesk_url . '/ticket.php?track=' . $ticket_info['trackid'] . '&e=' . rawurlencode($ticket_info['customer_email']);

            $old_status_text = array_search($old_status_id, $status_map) ?: 'N/A';
            $mail->isHTML(true);
            $mail->Subject = 'Pembaruan Status Tiket [#' . $ticket_info['trackid'] . ']';
            $mail->Body    = "Yth. " . htmlspecialchars($ticket_info['customer_name']) . ",<br><br>"
                           . "Status laporan Anda dengan subjek \"<b>" . htmlspecialchars($ticket_info['subject']) . "</b>\" telah diperbarui oleh staf kami.<br><br>"
                           . "Status Lama: <b>" . htmlspecialchars($old_status_text) . "</b><br>"
                           . "Status Update: <b>" . htmlspecialchars($status_text) . "</b><br><br>"
                           . "Untuk melihat detail tiket, silakan kunjungi tautan di bawah ini:<br>"
                           . "<a href=\"$tracking_url\">$tracking_url</a><br><br>"
                           . "Terima kasih.";
            
            $mail->send();
            $response = ['success' => true, 'message' => 'Tiket diperbarui dan notifikasi perubahan status telah dikirim.'];
        } catch (Exception $e) {
            $response = ['success' => true, 'message' => 'Tiket diperbarui, tetapi notifikasi email gagal. Error: ' . $mail->ErrorInfo];
        }
    } else {
        $response = ['success' => true, 'message' => 'Tiket berhasil diperbarui.'];
    }

} catch (Throwable $e) {
    if (isset($conn) && mysqli_ping($conn)) mysqli_rollback($conn);
    http_response_code(500);
    $response['message'] = 'Terjadi error di server: ' . $e->getMessage();
}

if (isset($conn) && mysqli_ping($conn)) mysqli_close($conn);
ob_end_clean();
echo json_encode($response);
exit();
?>
