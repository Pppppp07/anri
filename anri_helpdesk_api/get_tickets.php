<?php
require 'cors_handler.php';
ob_start();

require 'auth_check.php';
require 'koneksi.php';

$response = ['success' => false, 'data' => [], 'message' => 'Gagal mengambil data tiket.'];

try {
    $limit = 10;
    $page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
    $offset = ($page - 1) * $limit;

    // --- [AWAL PERUBAHAN] ---
    $sort_by = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'date'; // Ambil parameter sort
    // --- [AKHIR PERUBAHAN] ---

    $status_filter_text = isset($_GET['status']) ? trim($_GET['status']) : 'All';
    $category_filter = isset($_GET['category']) ? trim($_GET['category']) : 'All';
    $search_query = isset($_GET['q']) ? trim($_GET['q']) : '';
    $priority_filter_text = isset($_GET['priority']) ? trim($_GET['priority']) : 'All';
    $assignee_filter = isset($_GET['assignee']) ? trim($_GET['assignee']) : '';

    $sql = "SELECT t.id, t.trackid, t.name AS requester_name, t.subject, t.dt AS creation_date, t.lastchange, t.status, t.priority, t.lastreplier, t.message, t.replies, t.time_worked, t.due_date, c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name, t.custom1, t.custom2 FROM `hesk_tickets` AS t LEFT JOIN `hesk_categories` AS c ON t.category = c.id LEFT JOIN `hesk_users` AS o ON t.owner = o.id LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id";

    $conditions = [];
    $params = [];
    $types = '';

    // ... (SEMUA BLOK 'if' UNTUK FILTER TETAP SAMA) ...
    if (!empty($assignee_filter)) {
        if ($assignee_filter === 'Unassigned') { $conditions[] = "t.owner = 0"; } 
        else { $conditions[] = "LOWER(o.name) = LOWER(?)"; $params[] = $assignee_filter; $types .= 's'; }
    }
    $status_map = ['New' => 0, 'Waiting Reply' => 1, 'Replied' => 2, 'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5];
    if ($status_filter_text == 'All') {
        if (empty($assignee_filter) && $_GET['status'] !== 'Resolved') { $conditions[] = "t.status != ?"; $params[] = 3; $types .= 'i'; }
    } else if (array_key_exists($status_filter_text, $status_map)) {
        $conditions[] = "t.status = ?"; $params[] = $status_map[$status_filter_text]; $types .= 'i';
    }
    $priority_map_filter = ['Critical' => 0, 'High' => 1, 'Medium' => 2, 'Low' => 3];
    if ($priority_filter_text != 'All' && array_key_exists($priority_filter_text, $priority_map_filter)) {
        $conditions[] = "t.priority = ?"; $params[] = $priority_map_filter[$priority_filter_text]; $types .= 'i';
    }
    if ($category_filter != 'All') { $conditions[] = "t.category = ?"; $params[] = (int)$category_filter; $types .= 'i'; }
    if (!empty($search_query)) {
        $search_param = "%" . $search_query . "%";
        $conditions[] = "(t.subject LIKE ? OR t.trackid LIKE ? OR t.name LIKE ?)";
        array_push($params, $search_param, $search_param, $search_param);
        $types .= 'sss';
    }

    if (!empty($conditions)) { $sql .= " WHERE " . implode(" AND ", $conditions); }
    
    // --- [AWAL PERUBAHAN] ---
    // Tentukan klausa ORDER BY secara dinamis
    if ($sort_by === 'priority') {
        // Prioritas HESK: 0=Critical, 1=High, 2=Medium, 3=Low. Jadi urutkan ASC.
        $sql .= " ORDER BY t.priority ASC, t.lastchange DESC";
    } else {
        // Default urutkan berdasarkan tanggal
        $sql .= " ORDER BY t.lastchange DESC";
    }
    // --- [AKHIR PERUBAHAN] ---

    $sql .= " LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= 'ii';

    $stmt = mysqli_prepare($conn, $sql);
    if ($stmt === false) { throw new Exception('Query SQL Error: ' . mysqli_error($conn)); }
    if (!empty($params)) { mysqli_stmt_bind_param($stmt, $types, ...$params); }
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    $tickets = [];
    if ($result) {
        // ... (SISA DARI KODE WHILE LOOP UNTUK MEMPROSES DATA TETAP SAMA) ...
        $status_map_rev = [0 => 'New', 1 => 'Waiting Reply', 2 => 'Replied', 3 => 'Resolved', 4 => 'In Progress', 5 => 'On Hold'];
        $priority_map_rev = [ 0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low' ];
        while ($row = mysqli_fetch_assoc($result)) {
            $row['owner_name'] = $row['owner_name'] ?? 'Unassigned';
            $row['subject'] = html_entity_decode($row['subject'] ?? '', ENT_QUOTES, 'UTF-8');
            $row['requester_name'] = html_entity_decode($row['requester_name'] ?? '', ENT_QUOTES, 'UTF-8');
            $row['status_text'] = $status_map_rev[(int)$row['status']] ?? 'Unknown';
            $row['priority_text'] = $priority_map_rev[(int)$row['priority']] ?? 'Unknown';
            $prefix = ($row['lastreplier'] == '1') ? 'Staf: ' : '';
            $row['last_replier_text'] = isset($row['last_replier_name']) ? $prefix . $row['last_replier_name'] : '-';
            $tickets[] = $row;
        }
        $response['success'] = true;
        $response['data'] = $tickets;
        $response['message'] = "Data tiket berhasil diambil.";
    }
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