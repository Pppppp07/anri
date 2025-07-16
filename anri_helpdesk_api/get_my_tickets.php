<?php
require 'cors_handler.php';
ob_start();
require 'auth_check.php';
require 'koneksi.php';

$response = ['success' => false, 'data' => [], 'message' => 'Gagal mengambil data tiket.'];

try {
    $current_user_id = $GLOBALS['current_user_id'] ?? 0;
    if ($current_user_id === 0) {
        throw new Exception("Gagal mengidentifikasi pengguna dari token.");
    }

    $limit = 10;
    $page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
    $offset = ($page - 1) * $limit;
    
    $sort_by = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'date';
    $search_query = isset($_GET['q']) ? trim($_GET['q']) : '';
    $priority_filter_text = isset($_GET['priority']) ? trim($_GET['priority']) : 'All';
    $category_filter = isset($_GET['category']) ? trim($_GET['category']) : 'All';
    $status_filter_text = isset($_GET['status']) ? trim($_GET['status']) : 'All';

    $sql = "SELECT t.id, t.trackid, t.name AS requester_name, t.subject, t.dt AS creation_date, t.lastchange, t.status, t.priority, t.lastreplier, t.message, t.replies, t.time_worked, t.due_date, c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name, t.custom1, t.custom2 FROM `hesk_tickets` AS t LEFT JOIN `hesk_categories` AS c ON t.category = c.id LEFT JOIN `hesk_users` AS o ON t.owner = o.id LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id";

    $conditions = [];
    $params = [];
    $types = '';

    // Filter berdasarkan ID pengguna yang sedang login
    $conditions[] = "t.owner = ?";
    $params[] = $current_user_id;
    $types .= 'i';

    // Filter lainnya
    if ($priority_filter_text != 'All') {
        $priority_map = ['Critical' => 0, 'High' => 1, 'Medium' => 2, 'Low' => 3];
        if (array_key_exists($priority_filter_text, $priority_map)) {
            $conditions[] = "t.priority = ?";
            $params[] = $priority_map[$priority_filter_text];
            $types .= 'i';
        }
    }
    if ($category_filter != 'All') {
        $conditions[] = "t.category = ?";
        $params[] = (int)$category_filter;
        $types .= 'i';
    }
    if ($status_filter_text == 'Active') {
        $conditions[] = "t.status != ?";
        $params[] = 3;
        $types .= 'i';
    } elseif ($status_filter_text == 'Resolved') {
        $conditions[] = "t.status = ?";
        $params[] = 3;
        $types .= 'i';
    }

    // --- [AWAL BLOK PERBAIKAN] ---
    // Logika pencarian yang disamakan dengan get_tickets.php
    if (!empty($search_query)) {
        $search_param = "%" . $search_query . "%";
        // Menambahkan pencarian berdasarkan nama requester (t.name)
        $conditions[] = "(t.subject LIKE ? OR t.trackid LIKE ? OR t.name LIKE ?)";
        // Tambahkan parameter ketiga untuk t.name
        array_push($params, $search_param, $search_param, $search_param);
        // Tambahkan tipe 's' ketiga untuk string
        $types .= 'sss';
    }
    // --- [AKHIR BLOK PERBAIKAN] ---

    if (!empty($conditions)) { $sql .= " WHERE " . implode(" AND ", $conditions); }
    
    if ($sort_by === 'priority') {
        $sql .= " ORDER BY t.priority ASC, t.lastchange DESC";
    } else {
        $sql .= " ORDER BY t.lastchange DESC";
    }
    
    $sql .= " LIMIT ? OFFSET ?";
    array_push($params, $limit, $offset);
    $types .= 'ii';

    $stmt = mysqli_prepare($conn, $sql);
    if ($stmt === false) {
        throw new Exception('Query SQL Error: ' . mysqli_error($conn));
    }
    if (!empty($params)) {
        mysqli_stmt_bind_param($stmt, $types, ...$params);
    }
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    $tickets = [];
    while ($row = mysqli_fetch_assoc($result)) {
        $status_map = [0 => 'New', 1 => 'Waiting Reply', 2 => 'Replied', 3 => 'Resolved', 4 => 'In Progress', 5 => 'On Hold'];
        $priority_map_rev = [0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low'];

        $row['owner_name'] = $row['owner_name'] ?? 'Unassigned';
        $row['subject'] = html_entity_decode($row['subject'] ?? '', ENT_QUOTES, 'UTF-8');
        $row['requester_name'] = html_entity_decode($row['requester_name'] ?? '', ENT_QUOTES, 'UTF-8');
        $row['status_text'] = $status_map[(int)$row['status']] ?? 'Unknown';
        $row['priority_text'] = $priority_map_rev[(int)$row['priority']] ?? 'Unknown';
        $prefix = ($row['lastreplier'] == '1') ? 'Staf: ' : '';
        $row['last_replier_text'] = isset($row['last_replier_name']) ? $prefix . $row['last_replier_name'] : '-';
        $tickets[] = $row;
    }

    $response['success'] = true;
    $response['data'] = $tickets;
    mysqli_stmt_close($stmt);

} catch (Exception $e) {
    http_response_code(500);
    $response['message'] = "Terjadi kesalahan pada server: " . $e->getMessage();
}

ob_end_clean();
header('Content-Type: application/json');
mysqli_close($conn);
echo json_encode($response);
exit();
?>