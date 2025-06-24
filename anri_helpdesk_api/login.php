<?php
// Sertakan file koneksi database
require 'koneksi.php';

// PERBAIKAN 3: Menangani CORS Pre-flight request dari browser
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization");
    exit(0);
}

// Set header sebagai JSON
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");


// Buat array untuk respons
$response = array();

// Menerima data JSON yang dikirim dari Flutter
$data = json_decode(file_get_contents("php://input"));

// Pastikan data yang dibutuhkan ada
if (isset($data->username) && isset($data->password)) {
    // PERBAIKAN 2: mysqli_real_escape_string tidak diperlukan saat menggunakan prepared statements
    $username = $data->username;
    $password = $data->password;

    // Menggunakan Prepared Statements untuk Keamanan (Mencegah SQL Injection)
    $sql = "SELECT id, `user`, `pass`, `name`, `email` FROM `hesk_users` WHERE `user` = ?";
    
    // Siapkan statement
    $stmt = mysqli_prepare($conn, $sql);
    
    // Bind parameter
    mysqli_stmt_bind_param($stmt, "s", $username);
    
    // Eksekusi statement
    mysqli_stmt_execute($stmt);
    
    // Dapatkan hasilnya
    $result = mysqli_stmt_get_result($stmt);

    if (mysqli_num_rows($result) > 0) {
        // Jika user ditemukan, ambil datanya
        $row = mysqli_fetch_assoc($result);
        
        // Verifikasi password yang diinput dengan hash di database
        if (password_verify($password, $row['pass'])) {
            // Jika password cocok
            $response['success'] = true;
            $response['message'] = "Login berhasil!";
            
            // PERBAIKAN 1: Mengganti kunci 'data' menjadi 'user_data' agar sesuai dengan Flutter
            $response['user_data'] = array(
                'id' => (int)$row['id'], // Pastikan ID adalah integer
                'name' => $row['name'],
                'email' => $row['email'],
                'username' => $row['user']
            );
        } else {
            // Jika password salah
            $response['success'] = false;
            $response['message'] = "Username atau password salah.";
        }
    } else {
        // Jika user tidak ditemukan
        $response['success'] = false;
        $response['message'] = "Username tidak ditemukan.";
    }
    
    // Tutup statement
    mysqli_stmt_close($stmt);

} else {
    // Jika data tidak lengkap
    $response['success'] = false;
    $response['message'] = "Data tidak lengkap.";
}

// Tutup koneksi
mysqli_close($conn);

// Kembalikan respons dalam format JSON
echo json_encode($response);
?>