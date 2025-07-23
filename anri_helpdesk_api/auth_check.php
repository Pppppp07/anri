<?php
// Mulai output buffering
ob_start();

// 1. WAJIB: Muat autoloader, CORS, dan Koneksi di paling atas.
require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/cors_handler.php';
require_once __DIR__ . '/koneksi.php'; // <-- INI KUNCINYA, SEKARANG write_log() SUDAH TERSEDIA

// 2. SEKARANG kita aman untuk memulai logging
write_log("AUTH: Memulai auth_check.php untuk request: " . ($_SERVER['REQUEST_URI'] ?? 'Unknown URI'));

function get_bearer_token_debug() {
    $headers = getallheaders();
    // Log header hanya jika diperlukan untuk debug, bisa dinonaktifkan nanti
    // write_log("AUTH: Seluruh header yang diterima: " . json_encode($headers)); 
    $authHeader = $headers['Authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
    
    if ($authHeader !== null && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        write_log("AUTH: Header 'Authorization' ditemukan. Tipe: Bearer.");
        return $matches[1];
    }
    write_log("AUTH GAGAL: Header 'Authorization' dengan tipe 'Bearer' tidak ditemukan.");
    return null;
}

$token_from_user = get_bearer_token_debug();
if (!$token_from_user) {
    ob_end_clean(); // Bersihkan buffer sebelum output
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak ditemukan.']);
    exit();
}

$token_parts = explode(':', $token_from_user);
if (count($token_parts) !== 2) {
    ob_end_clean();
    http_response_code(401);
    write_log("AUTH GAGAL: Format token tidak valid (tidak mengandung ':'). Token diterima: " . $token_from_user);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Format token tidak valid.']);
    exit();
}
list($selector, $validator) = $token_parts;
write_log("AUTH: Token di-split. Selector: {$selector}");

$sql = "SELECT * FROM `hesk_auth_tokens` WHERE `selector` = ? AND `expires` >= NOW() LIMIT 1";
$stmt = mysqli_prepare($conn, $sql);
if ($stmt === false) {
    write_log("AUTH GAGAL: mysqli_prepare gagal: " . mysqli_error($conn));
    ob_end_clean();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Kesalahan server internal.']);
    exit();
}

mysqli_stmt_bind_param($stmt, "s", $selector);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

if ($auth_token_row = mysqli_fetch_assoc($result)) {
    write_log("AUTH: Ditemukan token di database untuk selector {$selector}.");
    
    $hashed_token_from_db = $auth_token_row['token'];
    $hashed_validator_from_user = hash('sha256', $validator);

    write_log("AUTH: Hash dari DB:   " . $hashed_token_from_db);
    write_log("AUTH: Hash dari User: " . $hashed_validator_from_user);

    if (!hash_equals($hashed_token_from_db, $hashed_validator_from_user)) {
        ob_end_clean();
        http_response_code(401);
        write_log("AUTH GAGAL: Token tidak cocok! (hash_equals gagal).");
        echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak cocok.']);
        exit();
    }
    
    write_log("AUTH SUKSES: Token cocok! Mencari detail user ID: " . $auth_token_row['user_id']);
    
    $user_id_from_token = $auth_token_row['user_id'];
    $sql_user = "SELECT id, name, user FROM hesk_users WHERE id = ? LIMIT 1";
    $stmt_user = mysqli_prepare($conn, $sql_user);
    mysqli_stmt_bind_param($stmt_user, "i", $user_id_from_token);
    mysqli_stmt_execute($stmt_user);
    $result_user = mysqli_stmt_get_result($stmt_user);

    if ($current_user_details = mysqli_fetch_assoc($result_user)) {
        write_log("AUTH SUKSES: User ditemukan: " . $current_user_details['name']);
        $GLOBALS['current_user_id'] = $current_user_details['id'];
        $GLOBALS['current_user_name'] = $current_user_details['name'];
    } else {
        ob_end_clean();
        http_response_code(401);
        write_log("AUTH GAGAL: User dari token (ID: {$user_id_from_token}) tidak ditemukan di tabel hesk_users.");
        echo json_encode(['success' => false, 'message' => 'Akses ditolak: Pengguna dari token tidak ditemukan.']);
        exit();
    }

} else {
    ob_end_clean();
    http_response_code(401);
    write_log("AUTH GAGAL: Token tidak valid atau kedaluwarsa (tidak ada hasil dari query SQL untuk selector: {$selector}).");
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak valid atau kedaluwarsa.']);
    exit();
}
?>