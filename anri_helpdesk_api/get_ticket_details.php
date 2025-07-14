<?php
require 'cors_handler.php';
ob_start();

require 'auth_check.php';
require 'koneksi.php';

$response = [
    'success' => false,
    'ticket_details' => null,
    'replies' => [],
    'attachments' => [],
    'message' => 'ID Tiket tidak valid atau tidak ditemukan.'
];

$ticket_id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($ticket_id > 0) {
    try {
        $sql_ticket = "SELECT t.*, c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name FROM `hesk_tickets` AS t LEFT JOIN `hesk_categories` AS c ON t.category = c.id LEFT JOIN `hesk_users` AS o ON t.owner = o.id LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id WHERE t.id = ? LIMIT 1";
        $stmt_ticket = mysqli_prepare($conn, $sql_ticket);
        mysqli_stmt_bind_param($stmt_ticket, 'i', $ticket_id);
        mysqli_stmt_execute($stmt_ticket);
        $result_ticket = mysqli_stmt_get_result($stmt_ticket);

        if ($ticket_details_raw = mysqli_fetch_assoc($result_ticket)) {
            
            // (Blok kode untuk memproses detail tiket, status, prioritas, dll. tetap sama)
            // ... (kode ini tidak perlu diubah dari versi sebelumnya)
            $status_map = [0 => 'New', 1 => 'Waiting Reply', 2 => 'Replied', 3 => 'Resolved', 4 => 'In Progress', 5 => 'On Hold'];
            $priority_map_rev = [0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low'];
            $prefix = ($ticket_details_raw['lastreplier'] == '1') ? 'Staf: ' : '';
            $ticket_details_safe = [
                'id' => (int)($ticket_details_raw['id'] ?? 0), 'trackid' => $ticket_details_raw['trackid'] ?? 'N/A',
                'requester_name' => $ticket_details_raw['name'] ?? 'Tidak diketahui', 'subject' => $ticket_details_raw['subject'] ?? '(Tanpa subjek)',
                'message' => $ticket_details_raw['message'] ?? '', 'creation_date' => $ticket_details_raw['dt'] ?? date('Y-m-d H:i:s'),
                'lastchange' => $ticket_details_raw['lastchange'] ?? date('Y-m-d H:i:s'), 'status_text' => $status_map[(int)($ticket_details_raw['status'] ?? 0)] ?? 'Unknown',
                'priority_text' => $priority_map_rev[(int)($ticket_details_raw['priority'] ?? 3)] ?? 'Unknown', 'category_name' => $ticket_details_raw['category_name'] ?? 'Tidak ada kategori',
                'owner_name' => $ticket_details_raw['owner_name'] ?? 'Unassigned', 'last_replier_text' => isset($ticket_details_raw['last_replier_name']) ? $prefix . $ticket_details_raw['last_replier_name'] : '-',
                'replies' => (int)($ticket_details_raw['replies'] ?? 0), 'time_worked' => $ticket_details_raw['time_worked'] ?? '00:00:00',
                'due_date' => $ticket_details_raw['due_date'], 'custom1' => $ticket_details_raw['custom1'] ?? '-', 'custom2' => $ticket_details_raw['custom2'] ?? '-',
            ];
            $response['ticket_details'] = $ticket_details_safe;

            $attachments_final = [];
            $attachment_string_from_ticket = $ticket_details_raw['attachments'];
            if (!empty($attachment_string_from_ticket)) {
                $attachment_list = array_filter(explode(',', $attachment_string_from_ticket));
                foreach ($attachment_list as $attachment_item) {
                    $item_parts = explode('#', $attachment_item, 2);
                    if (count($item_parts) == 2) {
                        $att_id = (int)$item_parts[0];
                        $sql_att_meta = "SELECT `real_name`, `saved_name`, `size` FROM `hesk_attachments` WHERE `att_id` = ? LIMIT 1";
                        $stmt_meta = mysqli_prepare($conn, $sql_att_meta);
                        mysqli_stmt_bind_param($stmt_meta, 'i', $att_id);
                        mysqli_stmt_execute($stmt_meta);
                        $result_meta = mysqli_stmt_get_result($stmt_meta);
                        if ($meta_row = mysqli_fetch_assoc($result_meta)) {
                             // --- PERBAIKAN UTAMA ADA DI SINI ---
                             // URL sekarang menunjuk ke gerbang download.php
                             $attachments_final[] = [
                                'id' => $att_id,
                                'real_name' => $meta_row['real_name'] ?? 'nama_file_tidak_ada',
                                'url' => 'http://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . '/download.php?file=' . urlencode($meta_row['saved_name']),
                                'size' => (int)($meta_row['size'] ?? 0)
                            ];
                        }
                        mysqli_stmt_close($stmt_meta);
                    }
                }
            }
            $response['attachments'] = $attachments_final;

            // ... (sisa kode untuk mengambil replies tetap sama)
            $sql_replies = "SELECT `id`, `name`, `message`, `dt` FROM `hesk_replies` WHERE `replyto` = ? ORDER BY `dt` ASC";
            $stmt_replies = mysqli_prepare($conn, $sql_replies);
            mysqli_stmt_bind_param($stmt_replies, 'i', $ticket_id);
            mysqli_stmt_execute($stmt_replies);
            $result_replies = mysqli_stmt_get_result($stmt_replies);
            $replies = [];
            while ($row = mysqli_fetch_assoc($result_replies)) {
                $row['id'] = (int)($row['id'] ?? 0); $row['name'] = $row['name'] ?? 'Tidak diketahui';
                $row['message'] = $row['message'] ?? ''; $row['dt'] = $row['dt'] ?? date('Y-m-d H:i:s');
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

ob_end_clean();
header('Content-Type: application/json');
mysqli_close($conn);
echo json_encode($response);
exit();
?>