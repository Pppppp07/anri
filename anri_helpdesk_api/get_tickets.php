<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'koneksi.php';
header('Content-Type: application/json');

// --- PENGATURAN PAGINATION DARI KODE TEMAN ANDA ---
$limit = 10;
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$offset = ($page - 1) * $limit;

// --- FILTER DINAMIS DARI KODE TEMAN ANDA ---
$status_filter_text = isset($_GET['status']) ? trim($_GET['status']) : 'All';
$category_filter = isset($_GET['category']) ? trim($_GET['category']) : 'All';

$status_map = [
    'New' => 0, 'Waiting Reply' => 1, 'Replied' => 2,
    'Resolved' => 3, 'In Progress' => 4, 'On Hold' => 5,
];

// --- QUERY SELECT LENGKAP DARI KODE ANDA ---
$sql = "SELECT
            t.id,
            t.trackid,
            t.name AS requester_name,
            t.subject,
            t.dt AS creation_date,
            t.lastchange,
            t.status,
            t.priority,
            t.lastreplier,
            c.name AS category_name,
            o.name AS owner_name,
            lr.name AS last_replier_name
        FROM
            `hesk_tickets` AS t
        LEFT JOIN `hesk_categories` AS c ON t.category = c.id
        LEFT JOIN `hesk_users` AS o ON t.owner = o.id
        LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id";

// --- LOGIKA WHERE DINAMIS DARI KODE TEMAN ANDA ---
$conditions = [];
$params = [];
$types = '';

if ($status_filter_text == 'All') {
    $conditions[] = "t.status != ?";
    $params[] = 3; // ID untuk 'Resolved'
    $types .= 'i';
} elseif (array_key_exists($status_filter_text, $status_map)) {
    $conditions[] = "t.status = ?";
    $params[] = $status_map[$status_filter_text];
    $types .= 'i';
}

if ($category_filter != 'All') {
    $conditions[] = "t.category = ?";
    $params[] = $category_filter;
    $types .= 'i';
}

if (!empty($conditions)) {
    $sql .= " WHERE " . implode(" AND ", $conditions);
}

// --- LOGIKA PENGURUTAN DARI KODE TEMAN ANDA ---
$sql .= " ORDER BY (t.priority = 0) DESC, t.dt DESC";

// --- LOGIKA PAGINATION DARI KODE TEMAN ANDA ---
$sql .= " LIMIT ? OFFSET ?";
$params[] = $limit;
$params[] = $offset;
$types .= 'ii';

// Eksekusi query dengan aman
$stmt = mysqli_prepare($conn, $sql);
if ($stmt === false) {
    echo json_encode(['success' => false, 'message' => 'Query SQL Error: ' . mysqli_error($conn)]);
    exit();
}
if (!empty($params)) {
    mysqli_stmt_bind_param($stmt, $types, ...$params);
}
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

// --- PEMROSESAN DATA & FORMAT OUTPUT "AMPLOP" DARI KODE ANDA ---
$response = array();
if ($result) {
    $response['success'] = true;
    $tickets = array();
    while ($row = mysqli_fetch_assoc($result)) {
        // Mapping numerik ke teks
        $row['status_text'] = array_search((int)$row['status'], $status_map, true) ?: 'Unknown';
        $row['priority_text'] = match ((int)$row['priority']) {
            0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low', default => 'Unknown',
        };
        if (is_null($row['owner_name'])) {
            $row['owner_name'] = 'Unassigned';
        }
        if (is_null($row['last_replier_name'])) {
            $row['last_replier_text'] = $row['requester_name'];
        } else {
            $prefix = ($row['lastreplier'] == '1') ? 'Staf: ' : '';
            $row['last_replier_text'] = $prefix . $row['last_replier_name'];
        }
        $tickets[] = $row;
    }
    $response['data'] = $tickets;
} else {
    $response['success'] = false;
    $response['message'] = "Gagal mengambil data tiket: " . mysqli_error($conn);
}

mysqli_stmt_close($stmt);
mysqli_close($conn);

echo json_encode($response);
?>