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

require 'koneksi.php';

// Menangani CORS Pre-flight request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization");
    exit(0);
}

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");

$response = array();
$data = json_decode(file_get_contents("php://input"));

if (isset($data->username) && isset($data->password)) {
    $username = $data->username;
    $password = $data->password;

    $sql = "SELECT id, `user`, `pass`, `name`, `email` FROM `hesk_users` WHERE `user` = ?";
    $stmt = mysqli_prepare($conn, $sql);
    mysqli_stmt_bind_param($stmt, "s", $username);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    if (mysqli_num_rows($result) > 0) {
        $row = mysqli_fetch_assoc($result);
        
        if (password_verify($password, $row['pass'])) {
            // --- PERUBAHAN UTAMA: MENAMBAHKAN TRY-CATCH UNTUK MENANGKAP ERROR ---
            try {
                // Jika password cocok, buat token
                $user_id = $row['id'];
                $selector = bin2hex(random_bytes(8));
                $validator = bin2hex(random_bytes(32));
                $hashed_validator = hash('sha256', $validator);
                $expires = date('Y-m-d H:i:s', time() + (30 * 24 * 60 * 60));

                // Mulai transaction untuk memastikan semua query berhasil
                mysqli_begin_transaction($conn);

                // Hapus token lama untuk user ini
                $delete_old_sql = "DELETE FROM `hesk_auth_tokens` WHERE `user_id` = ?";
                $stmt_delete = mysqli_prepare($conn, $delete_old_sql);
                mysqli_stmt_bind_param($stmt_delete, "i", $user_id);
                mysqli_stmt_execute($stmt_delete);
                mysqli_stmt_close($stmt_delete);

                // Masukkan token baru
                $sql_token = "INSERT INTO `hesk_auth_tokens` (`selector`, `token`, `user_id`, `expires`) VALUES (?, ?, ?, ?)";
                $stmt_token = mysqli_prepare($conn, $sql_token);
                mysqli_stmt_bind_param($stmt_token, "ssis", $selector, $hashed_validator, $user_id, $expires);
                
                // Jika insert gagal, lemparkan exception
                if (!mysqli_stmt_execute($stmt_token)) {
                    throw new Exception(mysqli_stmt_error($stmt_token));
                }
                mysqli_stmt_close($stmt_token);
                
                // Jika semua query berhasil, commit transaction
                mysqli_commit($conn);
                
                // Jika berhasil sampai sini, baru siapkan respons sukses
                $response['success'] = true;
                $response['message'] = "Login berhasil!";
                $response['user_data'] = array(
                    'id' => (int)$row['id'],
                    'name' => $row['name'],
                    'email' => $row['email'],
                    'username' => $row['user']
                );
                $response['token'] = $selector . ':' . $validator;

            } catch (Exception $e) {
                mysqli_rollback($conn); // Batalkan semua query jika ada yg gagal
                $response['success'] = false;
                // Pesan error sekarang akan lebih spesifik!
                $response['message'] = "Gagal membuat sesi token: " . $e->getMessage();
            }
            // --- AKHIR DARI PERUBAHAN ---

        } else {
            $response['success'] = false;
            $response['message'] = "Username atau password salah.";
        }
    } else {
        $response['success'] = false;
        $response['message'] = "Username tidak ditemukan.";
    }
    
    mysqli_stmt_close($stmt);

} else {
    $response['success'] = false;
    $response['message'] = "Data tidak lengkap.";
}

mysqli_close($conn);
echo json_encode($response);
?>