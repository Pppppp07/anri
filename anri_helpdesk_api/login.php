<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'koneksi.php';

// --- HEADER CORS ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
// --- AKHIR HEADER CORS ---

header('Content-Type: application/json');

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
            try {
                $user_id = $row['id'];
                
                // --- PERBAIKAN DI SINI ---
                // bin2hex(random_bytes(6)) akan menghasilkan string 12 karakter,
                // sesuai dengan skema database Anda (char(12)).
                $selector = bin2hex(random_bytes(6)); 
                $validator = bin2hex(random_bytes(32));
                
                $hashed_validator = hash('sha256', $validator);
                $expires = date('Y-m-d H:i:s', time() + (30 * 24 * 60 * 60));

                mysqli_begin_transaction($conn);

                $delete_old_sql = "DELETE FROM `hesk_auth_tokens` WHERE `user_id` = ?";
                $stmt_delete = mysqli_prepare($conn, $delete_old_sql);
                mysqli_stmt_bind_param($stmt_delete, "i", $user_id);
                mysqli_stmt_execute($stmt_delete);
                mysqli_stmt_close($stmt_delete);

                $sql_token = "INSERT INTO `hesk_auth_tokens` (`selector`, `token`, `user_id`, `expires`) VALUES (?, ?, ?, ?)";
                $stmt_token = mysqli_prepare($conn, $sql_token);
                mysqli_stmt_bind_param($stmt_token, "ssis", $selector, $hashed_validator, $user_id, $expires);
                
                if (!mysqli_stmt_execute($stmt_token)) {
                    throw new Exception(mysqli_stmt_error($stmt_token));
                }
                mysqli_stmt_close($stmt_token);
                
                mysqli_commit($conn);
                
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
                mysqli_rollback($conn);
                $response['success'] = false;
                $response['message'] = "Gagal membuat sesi token: " . $e->getMessage();
            }
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