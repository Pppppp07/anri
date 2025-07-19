<?php
// --- HEADER WAJIB UNTUK SEMUA ENDPOINT YANG BUTUH LOGIN ---
require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/cors_handler.php';
ob_start();

// Panggil auth_check.php. File ini sudah memanggil koneksi.php (yang berisi write_log).
require_once __DIR__ . '/auth_check.php';
// --- AKHIR HEADER WAJIB ---

$response = [
    'success' => false,
    'ticket_details' => null,
    'replies' => [],
    'attachments' => [], // Attachments untuk pesan utama
    'message' => 'ID Tiket tidak valid atau tidak ditemukan.'
];

$ticket_id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($ticket_id > 0) {
    try {
        // Ambil detail tiket utama
        $sql_ticket = "SELECT t.*, c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name FROM `hesk_tickets` AS t LEFT JOIN `hesk_categories` AS c ON t.category = c.id LEFT JOIN `hesk_users` AS o ON t.owner = o.id LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id WHERE t.id = ? LIMIT 1";
        $stmt_ticket = mysqli_prepare($conn, $sql_ticket);
        mysqli_stmt_bind_param($stmt_ticket, 'i', $ticket_id);
        mysqli_stmt_execute($stmt_ticket);
        $result_ticket = mysqli_stmt_get_result($stmt_ticket);

        if ($ticket_details_raw = mysqli_fetch_assoc($result_ticket)) {
            $status_map = [0 => 'New', 1 => 'Waiting Reply', 2 => 'Replied', 3 => 'Resolved', 4 => 'In Progress', 5 => 'On Hold'];
            $priority_map_rev = [0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low'];
            $prefix = ($ticket_details_raw['lastreplier'] == '1') ? 'Staf: ' : '';
            $response['ticket_details'] = [
                'id' => (int)$ticket_details_raw['id'], 'trackid' => $ticket_details_raw['trackid'],
                'requester_name' => $ticket_details_raw['name'], 'subject' => $ticket_details_raw['subject'],
                'message' => $ticket_details_raw['message'], 'creation_date' => $ticket_details_raw['dt'],
                'lastchange' => $ticket_details_raw['lastchange'], 'status_text' => $status_map[(int)$ticket_details_raw['status']],
                'priority_text' => $priority_map_rev[(int)$ticket_details_raw['priority']], 'category_name' => $ticket_details_raw['category_name'],
                'owner_name' => $ticket_details_raw['owner_name'] ?? 'Unassigned', 'last_replier_text' => isset($ticket_details_raw['last_replier_name']) ? $prefix . $ticket_details_raw['last_replier_name'] : '-',
                'replies' => (int)$ticket_details_raw['replies'], 'time_worked' => $ticket_details_raw['time_worked'],
                'due_date' => $ticket_details_raw['due_date'], 'custom1' => $ticket_details_raw['custom1'], 'custom2' => $ticket_details_raw['custom2'],
            ];

            // Proses attachment untuk pesan utama (logika yang sudah ada)
            $main_attachments = [];
            if (!empty($ticket_details_raw['attachments'])) {
                foreach (explode(',', $ticket_details_raw['attachments']) as $att_item) {
                    list($att_id, ) = explode('#', $att_item, 2);
                    $stmt_att = mysqli_prepare($conn, "SELECT `real_name`, `saved_name`, `size` FROM `hesk_attachments` WHERE `att_id` = ?");
                    mysqli_stmt_bind_param($stmt_att, 'i', $att_id);
                    mysqli_stmt_execute($stmt_att);
                    $meta = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_att));
                    if ($meta) {
                        $main_attachments[] = [
                            'id' => (int)$att_id, 'real_name' => $meta['real_name'],
                            'url' => 'http://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . '/download.php?file=' . urlencode($meta['saved_name']),
                            'size' => (int)$meta['size']
                        ];
                    }
                    mysqli_stmt_close($stmt_att);
                }
            }
            $response['attachments'] = $main_attachments;

            // Ambil semua balasan
            $sql_replies = "SELECT `id`, `name`, `message`, `dt`, `attachments` FROM `hesk_replies` WHERE `replyto` = ? ORDER BY `dt` ASC";
            $stmt_replies = mysqli_prepare($conn, $sql_replies);
            mysqli_stmt_bind_param($stmt_replies, 'i', $ticket_id);
            mysqli_stmt_execute($stmt_replies);
            $result_replies = mysqli_stmt_get_result($stmt_replies);
            
            $replies_final = [];
            while ($row = mysqli_fetch_assoc($result_replies)) {
                $reply_attachments = [];
                // Cek dan proses attachment untuk setiap balasan
                if (!empty($row['attachments'])) {
                     foreach (explode(',', $row['attachments']) as $att_item) {
                        list($att_id, ) = explode('#', $att_item, 2);
                        $stmt_att_reply = mysqli_prepare($conn, "SELECT `real_name`, `saved_name`, `size` FROM `hesk_attachments` WHERE `att_id` = ?");
                        mysqli_stmt_bind_param($stmt_att_reply, 'i', $att_id);
                        mysqli_stmt_execute($stmt_att_reply);
                        $meta_reply = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt_att_reply));
                        if ($meta_reply) {
                            $reply_attachments[] = [
                                'id' => (int)$att_id, 'real_name' => $meta_reply['real_name'],
                                'url' => 'http://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . '/download.php?file=' . urlencode($meta_reply['saved_name']),
                                'size' => (int)$meta_reply['size']
                            ];
                        }
                        mysqli_stmt_close($stmt_att_reply);
                    }
                }
                
                // Tambahkan balasan beserta lampirannya ke array final
                $replies_final[] = [
                    'id' => (int)$row['id'], 'name' => $row['name'],
                    'message' => $row['message'], 'dt' => $row['dt'],
                    'attachments' => $reply_attachments // Sertakan array lampiran di sini
                ];
            }
            $response['replies'] = $replies_final;
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