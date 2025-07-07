<?php
// Mulai output buffering untuk file ini juga.
ob_start();

// Hapus atau comment baris error reporting
/*
error_reporting(E_ALL);
ini_set('display_errors', 1);
*/

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

function get_bearer_token() {
    $authHeader = null;
    $headers = getallheaders();

    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    }

    if ($authHeader !== null) {
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            return $matches[1];
        }
    }
    return null;
}

$token_from_user = get_bearer_token();

if (!$token_from_user) {
    ob_clean(); // Bersihkan buffer sebelum mengirim error
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak ditemukan.']);
    exit();
}

// Pisahkan token
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
    // Jika sukses, jangan kirim output apa pun. Biarkan skrip pemanggil yang melanjutkan.

} else {
    ob_clean();
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak valid atau kedaluwarsa.']);
    exit();
}

// Jangan tutup koneksi, jangan bersihkan buffer jika valid, agar skrip pemanggil bisa lanjut.
// mysqli_close($conn);
?>