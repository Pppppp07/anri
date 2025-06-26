<?php
function get_bearer_token() {
    $headers = getallheaders();
    if (isset($headers['Authorization'])) {
        if (preg_match('/Bearer\s(\S+)/', $headers['Authorization'], $matches)) {
            return $matches[1];
        }
    }
    return null;
}

$token_from_user = get_bearer_token();

if (!$token_from_user) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak ditemukan.']);
    exit();
}

list($selector, $token) = explode(':', $token_from_user);

if (!$selector || !$token) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Format token tidak valid.']);
    exit();
}

require 'koneksi.php';

$sql = "SELECT * FROM `hesk_auth_tokens` WHERE `selector` = ? AND `expires` >= NOW() LIMIT 1";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "s", $selector);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

if ($auth_token_row = mysqli_fetch_assoc($result)) {
    // Token ditemukan dan belum kedaluwarsa, verifikasi isinya
    $hashed_token_from_db = $auth_token_row['token'];
    $hashed_token_from_user = hash('sha256', $token);

    if (!hash_equals($hashed_token_from_db, $hashed_token_from_user)) {
        // Token tidak cocok, upaya peretasan?
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak cocok.']);
        exit();
    }
    
    // Sukses! Token valid.
    // Anda bisa mengambil data user di sini jika perlu
    // $user_id = $auth_token_row['user_id'];

} else {
    // Token tidak ditemukan atau sudah kedaluwarsa
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak valid atau kedaluwarsa.']);
    exit();
}

// Jangan tutup koneksi di sini, karena akan digunakan oleh skrip pemanggil
// mysqli_close($conn);
?>