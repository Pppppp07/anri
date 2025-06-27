<?php
// --- HEADER CORS UNTUK MENGIZINKAN AKSES DARI FLUTTER WEB ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Menangani Pre-flight Request (penting untuk browser)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
error_reporting(E_ALL);
ini_set('display_errors', 1);

// AMANKAN ENDPOINT INI
require 'auth_check.php';
// Memanggil file koneksi
require 'koneksi.php';

header('Content-Type: application/json');

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

// Query SELECT tetap sama
$sql = "SELECT
            t.id, t.trackid, t.name AS requester_name, t.subject,
            t.dt AS creation_date, t.lastchange, t.status, t.priority,
            t.lastreplier, t.message, t.replies, t.time_worked, t.due_date,
            c.name AS category_name, o.name AS owner_name, lr.name AS last_replier_name
        FROM `hesk_tickets` AS t
        LEFT JOIN `hesk_categories` AS c ON t.category = c.id
        LEFT JOIN `hesk_users` AS o ON t.owner = o.id
        LEFT JOIN `hesk_users` AS lr ON t.replierid = lr.id";

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

// --- PERBAIKAN: Logika WHERE dan ORDER BY dipisahkan untuk prioritas pencarian ---
$search_param = "";
if (!empty($search_query)) {
    $search_param = "%" . $search_query . "%";
    // Klausa WHERE tetap mencari di semua kolom yang relevan
    $conditions[] = "(t.name LIKE ? OR t.subject LIKE ? OR t.trackid LIKE ? OR c.name LIKE ? OR o.name LIKE ?)";
    // Tambahkan parameter untuk klausa WHERE
    array_push($params, $search_param, $search_param, $search_param, $search_param, $search_param);
    $types .= 'sssss';
}

if (!empty($conditions)) {
    $sql .= " WHERE " . implode(" AND ", $conditions);
}

// --- PERBAIKAN: Logika Pengurutan dengan Prioritas Pencarian ---
if (!empty($search_query)) {
    // Urutkan berdasarkan prioritas kolom pencarian: 1. nama, 2. subjek, 3. ID tiket, lalu kriteria default.
    $sql .= " ORDER BY 
                CASE 
                    WHEN t.name LIKE ? THEN 1 
                    WHEN t.subject LIKE ? THEN 2 
                    WHEN t.trackid LIKE ? THEN 3 
                    ELSE 4 
                END, 
                (t.priority = 0) DESC, 
                t.lastchange DESC";
    // Tambahkan parameter untuk klausa ORDER BY
    array_push($params, $search_param, $search_param, $search_param);
    $types .= 'sss';
} else {
    // Logika pengurutan default jika tidak ada pencarian
    $sql .= " ORDER BY (t.priority = 0) DESC, t.lastchange DESC";
}

// Logika Pagination
$sql .= " LIMIT ? OFFSET ?";
$params[] = $limit;
$params[] = $offset;
$types .= 'ii';

// Eksekusi Query dengan Aman
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

// Proses Hasil (Tidak ada perubahan di bagian ini)
$response = [];
$tickets = [];
if ($result) {
    while ($row = mysqli_fetch_assoc($result)) {
        $row['status_text'] = array_search((int)$row['status'], $status_map, true) ?: 'Unknown';
        $row['priority_text'] = match ((int)$row['priority']) {
            0 => 'Critical', 1 => 'High', 2 => 'Medium', 3 => 'Low', default => 'Unknown',
        };

        if (is_null($row['owner_name'])) {
            $row['owner_name'] = 'Unassigned';
        }

        if (is_null($row['last_replier_name'])) {
            $row['last_replier_text'] = null;
        } else {
            $prefix = ($row['lastreplier'] == '1') ? 'Staf: ' : '';
            $row['last_replier_text'] = $prefix . $row['last_replier_name'];
        }

        $tickets[] = $row;
    }
    $response['success'] = true;
    $response['data'] = $tickets;
} else {
    $response['success'] = false;
    $response['message'] = "Gagal mengambil data tiket.";
}

mysqli_stmt_close($stmt);
mysqli_close($conn);

echo json_encode($response);
?>