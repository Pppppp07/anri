<?php
ob_start();

require 'cors_handler.php';

function get_bearer_token() {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
    if ($authHeader !== null && preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        return $matches[1];
    }
    return null;
}

$token_from_user = get_bearer_token();
if (!$token_from_user) {
    ob_clean();
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak ditemukan.']);
    exit();
}

$token_parts = explode(':', $token_from_user);
if (count($token_parts) !== 2) {
    ob_clean();
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Format token tidak valid.']);
    exit();
}
list($selector, $token) = $token_parts;

require 'koneksi.php';

$sql = "SELECT * FROM `hesk_auth_tokens` WHERE `selector` = ? AND `expires` >= NOW() LIMIT 1";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "s", $selector);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

if ($auth_token_row = mysqli_fetch_assoc($result)) {
    $hashed_token_from_db = $auth_token_row['token'];
    $hashed_token_from_user = hash('sha256', $token);

    if (!hash_equals($hashed_token_from_db, $hashed_token_from_user)) {
        ob_clean();
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak cocok.']);
        exit();
    }
    
    // --- BARU: Sediakan info pengguna yang login untuk file lain ---
    $user_id_from_token = $auth_token_row['user_id'];
    $sql_user = "SELECT id, name, user FROM hesk_users WHERE id = ? LIMIT 1";
    $stmt_user = mysqli_prepare($conn, $sql_user);
    mysqli_stmt_bind_param($stmt_user, "i", $user_id_from_token);
    mysqli_stmt_execute($stmt_user);
    $result_user = mysqli_stmt_get_result($stmt_user);

    if ($current_user_details = mysqli_fetch_assoc($result_user)) {
        // Definisikan variabel global untuk digunakan oleh file yang memanggil skrip ini
        $GLOBALS['current_user_id'] = $current_user_details['id'];
        $GLOBALS['current_user_name'] = $current_user_details['name'];
    } else {
        ob_clean();
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Akses ditolak: Pengguna dari token tidak ditemukan.']);
        exit();
    }
    // --- AKHIR BLOK BARU ---

} else {
    ob_clean();
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak valid atau kedaluwarsa.']);
    exit();
}
?>