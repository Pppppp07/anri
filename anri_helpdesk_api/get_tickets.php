<?php
ob_start();

// AMANKAN ENDPOINT INI
require 'auth_check.php';
// Memanggil file koneksi
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

$response = ['success' => false, 'data' => [], 'message' => 'Gagal mengambil data tiket.'];

try {
    // --- PENGATURAN PAGINATION ---
    $limit = 10;
    $page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
    $offset = ($page - 1) * $limit;

    // --- FILTER DINAMIS ---
    $status_filter_text = isset($_GET['status']) ? trim($_GET['status']) : 'All';
    $category_filter = isset($_GET['category']) ? trim($_GET['category']) : 'All';
    $search_query = isset($_GET['search']) ? trim($_GET['search']) : '';

    $status_map = [
        'New' => 0, 'Waiting Reply' => 1, 'Replied' => 2,
        'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5,
    ];

    $sql = "SELECT t.id, t.trackid, t.name AS requester_name, t.subject, t.dt AS creation_date, t.lastchange, t.status, t.priority, t.lastreplier, t.message, t.replies, t.time_worked, t.due_date, c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name, t.custom1, t.custom2 FROM `hesk_tickets` AS t LEFT JOIN `hesk_categories` AS c ON t.category = c.id LEFT JOIN `hesk_users` AS o ON t.owner = o.id LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id";

    $conditions = [];
    $params = [];
    $types = '';

    // Filter Status
    if ($status_filter_text == 'All') {
        $conditions[] = "t.status != ?";
        $params[] = 3; // ID untuk 'Resolved'
        $types .= 'i';
    } 
    else if (array_key_exists($status_filter_text, $status_map)) {
        $conditions[] = "t.status = ?";
        $params[] = $status_map[$status_filter_text];
        $types .= 'i';
    }

    // Filter Kategori
    if ($category_filter != 'All') {
        $conditions[] = "t.category = ?";
        $params[] = (int)$category_filter;
        $types .= 'i';
    }
    
    $search_param = "";
    if (!empty($search_query)) {
        $search_param = "%" . $search_query . "%";
        $conditions[] = "(t.name LIKE ? OR t.subject LIKE ? OR t.trackid LIKE ? OR c.name LIKE ? OR o.name LIKE ?)";
        array_push($params, $search_param, $search_param, $search_param, $search_param, $search_param);
        $types .= 'sssss';
    }

    if (!empty($conditions)) {
        $sql .= " WHERE " . implode(" AND ", $conditions);
    }

    if (!empty($search_query)) {
        $sql .= " ORDER BY CASE WHEN t.name LIKE ? THEN 1 WHEN t.subject LIKE ? THEN 2 WHEN t.trackid LIKE ? THEN 3 ELSE 4 END, (t.priority = 0) DESC, t.lastchange DESC";
        array_push($params, $search_param, $search_param, $search_param);
        $types .= 'sss';
    } else {
        $sql .= " ORDER BY (t.priority = 0) DESC, t.lastchange DESC";
    }

    $sql .= " LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
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
    if ($result) {
        while ($row = mysqli_fetch_assoc($result)) {
            $row['subject'] = html_entity_decode($row['subject'] ?? '', ENT_QUOTES, 'UTF-8');
            $row['requester_name'] = html_entity_decode($row['requester_name'] ?? '', ENT_QUOTES, 'UTF-8');
            $row['status_text'] = array_search((int)$row['status'], $status_map, true) ?: 'Unknown';
            $row['priority_text'] = match ((int)$row['priority']) {
                0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low', default => 'Unknown',
            };
            $row['owner_name'] = $row['owner_name'] ?? 'Unassigned';
            $prefix = ($row['lastreplier'] == '1') ? 'Staf: ' : '';
            $row['last_replier_text'] = isset($row['last_replier_name']) ? $prefix . $row['last_replier_name'] : null;
            $tickets[] = $row;
        }
        $response['success'] = true;
        $response['data'] = $tickets;
        $response['message'] = "Data tiket berhasil diambil.";
    }
    mysqli_stmt_close($stmt);

} catch (Exception $e) {
    $response['message'] = "Terjadi kesalahan pada server: " . $e->getMessage();
}

// --- BAGIAN AKHIR ---
ob_clean();
header('Content-Type: application/json');
mysqli_close($conn);
echo json_encode($response);
exit();
?>