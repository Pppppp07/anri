<?php
ob_start();

require 'cors_handler.php';
require 'auth_check.php';
require 'koneksi.php';

header('Content-Type: application/json');

$response = ['success' => false, 'message' => 'Terjadi kesalahan yang tidak diketahui.'];

try {
    $ticket_id = isset($_POST['ticket_id']) ? (int)$_POST['ticket_id'] : 0;
    $status_text = isset($_POST['status']) ? trim($_POST['status']) : '';
    $priority_text = isset($_POST['priority']) ? trim($_POST['priority']) : '';
    $category_name = isset($_POST['category_name']) ? trim($_POST['category_name']) : '';
    $owner_name = isset($_POST['owner_name']) ? trim($_POST['owner_name']) : '';
    $time_worked = isset($_POST['time_worked']) ? trim($_POST['time_worked']) : '00:00:00';
    $due_date_str = isset($_POST['due_date']) ? trim($_POST['due_date']) : '';

    if (empty($ticket_id)) {
        throw new Exception('Ticket ID tidak boleh kosong.');
    }

    $status_map = ['New' => 0, 'Waiting Reply' => 1, 'Replied' => 2, 'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5];
    $status_id = $status_map[$status_text] ?? 0;

    // --- PERBAIKAN FINAL: Menggunakan mapping ID 0-3 sesuai skema DB ---
    $priority_map = [
        'Critical' => 0,
        'High'     => 1,
        'Medium'   => 2,
        'Low'      => 3,
    ];
    // Default ke 3 (Low) jika tidak ditemukan
    $priority_id = $priority_map[$priority_text] ?? 3;
    // --- AKHIR PERBAIKAN ---

    $category_id = null;
    $stmt_cat = mysqli_prepare($conn, "SELECT id FROM `hesk_categories` WHERE `name` = ? LIMIT 1");
    mysqli_stmt_bind_param($stmt_cat, 's', $category_name);
    mysqli_stmt_execute($stmt_cat);
    $result_cat = mysqli_stmt_get_result($stmt_cat);
    if ($row_cat = mysqli_fetch_assoc($result_cat)) {
        $category_id = $row_cat['id'];
    }
    mysqli_stmt_close($stmt_cat);

    $owner_id = 0; // Default ke 0 (Unassigned)
    if ($owner_name !== 'Unassigned' && !empty($owner_name)) {
        $stmt_user = mysqli_prepare($conn, "SELECT id FROM `hesk_users` WHERE `name` = ? LIMIT 1");
        mysqli_stmt_bind_param($stmt_user, 's', $owner_name);
        mysqli_stmt_execute($stmt_user);
        $result_user = mysqli_stmt_get_result($stmt_user);
        if ($row_user = mysqli_fetch_assoc($result_user)) {
            $owner_id = $row_user['id'];
        }
        mysqli_stmt_close($stmt_user);
    }
    
    $due_date_param = empty($due_date_str) ? NULL : $due_date_str;

    $sql = "UPDATE `hesk_tickets` SET `status` = ?, `priority` = ?, `category` = ?, `owner` = ?, `time_worked` = ?, `due_date` = ?, `lastchange` = NOW() WHERE `id` = ?";
    $stmt = mysqli_prepare($conn, $sql);
    if (!$stmt) { throw new Exception('Gagal mempersiapkan statement SQL: ' . mysqli_error($conn)); }
    
    mysqli_stmt_bind_param($stmt, 'iiiissi', $status_id, $priority_id, $category_id, $owner_id, $time_worked, $due_date_param, $ticket_id);

    if (mysqli_stmt_execute($stmt)) {
        $response['success'] = true;
        $response['message'] = 'Tiket berhasil diperbarui.';
    } else {
        throw new Exception('Gagal memperbarui tiket di database: ' . mysqli_stmt_error($stmt));
    }
    mysqli_stmt_close($stmt);

} catch (Exception $e) {
    http_response_code(500);
    $response['success'] = false;
    $response['message'] = $e->getMessage();
}

ob_end_clean();
echo json_encode($response);
mysqli_close($conn);
exit();
?>