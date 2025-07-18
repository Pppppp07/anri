<?php
/**
 * add_reply.php
 * VERSI FINAL GABUNGAN - Menggabungkan semua fitur dengan benar.
 */

// Mulai output buffering untuk memastikan tidak ada output liar.
ob_start();

// Matikan tampilan error langsung ke output untuk mencegah kerusakan JSON.
error_reporting(0);
ini_set('display_errors', 0);

require 'koneksi.php';
require 'auth_check.php';
require 'notification_email.php';

header("Access-Control-Allow-Origin: *");
header("Access-control-allow-methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { http_response_code(200); exit(); }
header('Content-Type: application/json');

$response = ['success' => false, 'message' => 'Terjadi kesalahan.'];
$attach_dir = str_replace('/', DIRECTORY_SEPARATOR, $_SERVER['DOCUMENT_ROOT'] . '/hesk/attachments');

try {
    // Validasi direktori lampiran
    if (!is_dir($attach_dir) || !is_writable($attach_dir)) {
        throw new Exception('Direktori lampiran tidak dapat diakses. Periksa path dan izin folder.');
    }
    
    // Ambil semua data dari POST
    $ticket_id  = isset($_POST['ticket_id']) ? intval($_POST['ticket_id']) : 0;
    $staff_id   = isset($_POST['staff_id']) ? intval($_POST['staff_id']) : 1;
    $staff_name = isset($_POST['staff_name']) ? trim($_POST['staff_name']) : 'Administrator';
    $status_txt = isset($_POST['new_status']) ? trim($_POST['new_status']) : '';
    $message_raw = isset($_POST['message']) ? trim($_POST['message']) : '';

    // Validasi input
    if (!$ticket_id || empty($message_raw) || empty($status_txt)) {
        throw new Exception('Data yang dikirim tidak lengkap (ID Tiket, Pesan, atau Status baru tidak boleh kosong).');
    }

    // [FIX PESAN] Siapkan pesan dalam format Teks dan HTML, meniru HESK
    $message_html = nl2br(htmlspecialchars($message_raw));
    $message_text = htmlspecialchars($message_raw);

    mysqli_begin_transaction($conn);

    // Ambil Tracking ID untuk penamaan file & email
    $sql_trackid = "SELECT `trackid`, `name` AS customer_name, `email` AS customer_email, `subject` FROM `hesk_tickets` WHERE `id` = ? LIMIT 1";
    $stmt_trackid = mysqli_prepare($conn, $sql_trackid);
    mysqli_stmt_bind_param($stmt_trackid, 'i', $ticket_id);
    mysqli_stmt_execute($stmt_trackid);
    $ticket_info = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_trackid));
    mysqli_stmt_close($stmt_trackid);

    if (!$ticket_info) {
        throw new Exception('Gagal mendapatkan informasi tiket.');
    }
    $trackid = $ticket_info['trackid'];

    // Proses lampiran file (logika yang sudah benar)
    $attachments_for_db = '';
    if (!empty($_FILES['attachments']['name'][0])) {
        $uploaded_attachments = [];
        foreach ($_FILES['attachments']['name'] as $i => $name) {
            if ($_FILES['attachments']['error'][$i] !== UPLOAD_ERR_OK) { continue; }

            $real_name = basename($name);
            $file_tmp = $_FILES['attachments']['tmp_name'][$i];
            $file_size = $_FILES['attachments']['size'][$i];
            $ext = strtolower(pathinfo($real_name, PATHINFO_EXTENSION));
            $random_hash = md5(microtime() . $ticket_id . $real_name);
            $saved_name = $trackid . '_' . $random_hash . '.' . $ext;
            
            if (!move_uploaded_file($file_tmp, $attach_dir . DIRECTORY_SEPARATOR . $saved_name)) {
                throw new Exception('Gagal memindahkan file lampiran.');
            }

            $sql_att = "INSERT INTO `hesk_attachments` (`ticket_id`, `saved_name`, `real_name`, `size`, `type`) VALUES (?, ?, ?, ?, '0')";
            $stmt_att = mysqli_prepare($conn, $sql_att);
            mysqli_stmt_bind_param($stmt_att, 'sssi', $trackid, $saved_name, $real_name, $file_size);
            mysqli_stmt_execute($stmt_att);
            $att_id = mysqli_insert_id($conn);
            mysqli_stmt_close($stmt_att);

            $uploaded_attachments[] = $att_id . '#' . $real_name;
        }
        if (!empty($uploaded_attachments)) { $attachments_for_db = implode(',', $uploaded_attachments); }
    }

    // [FIX PESAN] Query INSERT sekarang mengisi `message` dan `message_html`
    $sql_reply = "INSERT INTO `hesk_replies` (`replyto`, `name`, `message`, `message_html`, `dt`, `staffid`, `attachments`) VALUES (?, ?, ?, ?, NOW(), ?, ?)";
    $stmt_reply = mysqli_prepare($conn, $sql_reply);
    mysqli_stmt_bind_param($stmt_reply, 'isssis', $ticket_id, $staff_name, $message_text, $message_html, $staff_id, $attachments_for_db);
    mysqli_stmt_execute($stmt_reply);

    // Update status tiket
    $status_map = ['New'=>0, 'Waiting Reply'=>1, 'Replied'=>2, 'Resolved'=>3, 'In Progress'=>4, 'On Hold'=>5];
    $new_status_id = $status_map[$status_txt];
    $sql_update = "UPDATE `hesk_tickets` SET `status`=?, `lastchange`=NOW(), `replies`=`replies`+1, `staffreplies`=`staffreplies`+1, `lastreplier`='1', `replierid`=? WHERE `id`=?";
    $stmt_update = mysqli_prepare($conn, $sql_update);
    mysqli_stmt_bind_param($stmt_update, 'iii', $new_status_id, $staff_id, $ticket_id);
    mysqli_stmt_execute($stmt_update);
    
    mysqli_commit($conn);
    
    // [FIX EMAIL] Kirim notifikasi email ke customer
    $hesk_url = rtrim($_ENV['HESK_URL'] ?? 'http://localhost/hesk', '/');
    $tracking_url = $hesk_url . '/ticket.php?track=' . $trackid . '&e=' . rawurlencode($ticket_info['customer_email']);
    $subject = '[#' . $trackid .'] Balasan Baru: ' . $ticket_info['subject'];
    $body = "<p>Yth. " . htmlspecialchars($ticket_info['customer_name']) . ",</p>"
          . "<p>Staf kami telah memberikan balasan untuk tiket Anda:</p>"
          . "<div style='border-left: 3px solid #E4E4E4; padding-left: 15px; margin: 15px 0;'>" . $message_html . "</div>"
          . (!empty($attachments_for_db) ? "<p>Admin Melampirkan File.</p>" : "")
          . "<p>Anda dapat melihat detail dan membalas kembali melalui tautan di bawah ini:<br>"
          . "<a href=\"$tracking_url\">$tracking_url</a></p>"
          . "<p>Hormat kami,<br>Tim Helpdesk</p>";

    send_notification_email($ticket_info['customer_email'], $ticket_info['customer_name'], $subject, $body);
    
    $response = ['success' => true, 'message' => 'Balasan berhasil dikirim dan notifikasi telah diproses.'];

} catch (Exception $e) {
    if ($conn) { mysqli_rollback($conn); }
    http_response_code(500);
    $response['message'] = 'Gagal memproses balasan: ' . $e->getMessage();
    // Catat error ke log server untuk dianalisis nanti
    error_log("ANRI Helpdesk API Error: " . $e->getMessage());
}

if ($conn) mysqli_close($conn);

// Bersihkan semua kemungkinan output 'liar' sebelum mengirim JSON
ob_end_clean();
echo json_encode($response);
exit();
?>