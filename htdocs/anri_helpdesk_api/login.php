<?php
ob_start();


require_once __DIR__ . '/vendor/autoload.php';


require_once __DIR__ . '/koneksi.php';
require_once __DIR__ . '/cors_handler.php';


$response = ['success' => false, 'message' => 'Terjadi kesalahan yang tidak diketahui.'];

// Ambil data JSON dari body request
$data = json_decode(file_get_contents("php://input"));

// Pastikan data yang diterima tidak kosong dan merupakan objek yang valid
if (is_object($data) && isset($data->username) && isset($data->password)) {
    $username = $data->username;
    $password = $data->password;

    // Gunakan prepared statement untuk keamanan
    $sql = "SELECT id, `user`, `pass`, `name`, `email` FROM `hesk_users` WHERE `user` = ?";
    $stmt = mysqli_prepare($conn, $sql);

    if ($stmt) {
        mysqli_stmt_bind_param($stmt, "s", $username);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);

        if (mysqli_num_rows($result) > 0) {
            $row = mysqli_fetch_assoc($result);

            // Verifikasi password
            if (password_verify($password, $row['pass'])) {
                try {
                    $user_id = $row['id'];

                    // Logika pembuatan token
                    $selector = bin2hex(random_bytes(6));
                    $validator = bin2hex(random_bytes(32));
                    $hashed_validator = hash('sha256', $validator);
                    $expires = date('Y-m-d H:i:s', time() + (30 * 24 * 60 * 60)); // 30 hari

                    // Gunakan transaksi untuk memastikan konsistensi data
                    mysqli_begin_transaction($conn);

                    // Hapus token lama
                    $delete_old_sql = "DELETE FROM `hesk_auth_tokens` WHERE `user_id` = ?";
                    $stmt_delete = mysqli_prepare($conn, $delete_old_sql);
                    mysqli_stmt_bind_param($stmt_delete, "i", $user_id);
                    mysqli_stmt_execute($stmt_delete);
                    mysqli_stmt_close($stmt_delete);

                    // Masukkan token baru
                    $sql_token = "INSERT INTO `hesk_auth_tokens` (`selector`, `token`, `user_id`, `expires`) VALUES (?, ?, ?, ?)";
                    $stmt_token = mysqli_prepare($conn, $sql_token);
                    mysqli_stmt_bind_param($stmt_token, "ssis", $selector, $hashed_validator, $user_id, $expires);

                    if (!mysqli_stmt_execute($stmt_token)) {
                        throw new Exception('Gagal menyimpan sesi token: ' . mysqli_stmt_error($stmt_token));
                    }
                    mysqli_stmt_close($stmt_token);

                    mysqli_commit($conn);

                    // Siapkan response sukses
                    $response['success'] = true;
                    $response['message'] = "Login berhasil!";
                    $response['user_data'] = [
                        'id' => (int)$row['id'],
                        'name' => $row['name'],
                        'email' => $row['email'],
                        'username' => $row['user']
                    ];
                    $response['token'] = $selector . ':' . $validator;

                } catch (Exception $e) {
                    mysqli_rollback($conn);
                    $response['message'] = "Kesalahan pada server: " . $e->getMessage();
                }
            } else {
                $response['message'] = "Username atau password salah.";
            }
        } else {
            $response['message'] = "Username tidak ditemukan.";
        }
        mysqli_stmt_close($stmt);
    } else {
        $response['message'] = 'Gagal mempersiapkan statement SQL: ' . mysqli_error($conn);
    }
} else {
    $response['message'] = "Data tidak lengkap. Pastikan username dan password dikirim.";
}


// Bersihkan semua output yang mungkin sudah ada (termasuk notice/warning PHP)
ob_clean();

// Set header sebagai JSON
header('Content-Type: application/json');

// Tutup koneksi database
mysqli_close($conn);

// Cetak response sebagai JSON murni
echo json_encode($response);

// Hentikan eksekusi skrip
exit();
?>