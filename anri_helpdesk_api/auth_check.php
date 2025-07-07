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

// --- FUNGSI INI DISEMPURNAKAN AGAR LEBIH TANGGUH ---
function get_bearer_token() {
    $authHeader = null;
    $headers = getallheaders();

    // Coba ambil header dari berbagai kemungkinan sumber
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        // Fallback untuk beberapa konfigurasi server Apache
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        // Fallback lain yang terkadang diperlukan setelah RewriteRule .htaccess
        $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    }

    if ($authHeader !== null) {
        // Jika header ditemukan, ekstrak token dari format "Bearer <token>"
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            return $matches[1];
        }
    }

    // Jika tidak ada header atau token tidak ditemukan, kembalikan null
    return null;
}
// --- AKHIR DARI PENYEMPURNAAN FUNGSI ---

$token_from_user = get_bearer_token();

if (!$token_from_user) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Akses ditolak: Token tidak ditemukan.']);
    exit();
}

// Logika Anda selanjutnya tidak berubah
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