<?php
/**
 * File: send_notification.php (Versi Final Produksi)
 * Deskripsi: Skrip ini dijalankan dari command line untuk mengirim notifikasi.
 */

// Cek apakah skrip dijalankan dari command line.
if (php_sapi_name() !== 'cli') {
    die("This script can only be run from the command line.");
}

// Cek jumlah argumen.
if ($argc < 5) {
    // Menulis ke log error PHP jika ada pemanggilan yang salah.
    error_log("FCM Script Error: Argumen tidak lengkap. Diterima $argc, butuh 5.");
    die("Usage: php " . $argv[0] . " [user_id] \"[title]\" \"[body]\" \"[ticket_id]\"\n");
}

// Ambil argumen dari command line.
$user_id = (int)$argv[1];
$title = $argv[2];
$body = $argv[3];
$ticket_id = $argv[4];

// Muat semua dependensi.
require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/koneksi.php';

function send_fcm_notification_final(mysqli $conn, int $user_id, string $title, string $body, string $ticket_id) {
    
    // 1. Ambil FCM token.
    $sql = "SELECT `fcm_token` FROM `hesk_users` WHERE `id` = ? AND `fcm_token` IS NOT NULL AND `fcm_token` != '' LIMIT 1";
    $stmt = mysqli_prepare($conn, $sql);
    mysqli_stmt_bind_param($stmt, 'i', $user_id);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    if ($row = mysqli_fetch_assoc($result)) {
        $token = $row['fcm_token'];
    } else {
        mysqli_stmt_close($stmt);
        return; // Hentikan jika user tidak punya token.
    }
    mysqli_stmt_close($stmt);

    // 2. Otentikasi Google.
    try {
        $client = new Google\Client();
        $client->setAuthConfig(__DIR__ . '/service-account-key.json');
        $client->addScope('https://www.googleapis.com/auth/firebase.messaging');
        $client->fetchAccessTokenWithAssertion();
        $accessToken = $client->getAccessToken()['access_token'];
    } catch (Exception $e) {
        error_log('FCM Auth Error: ' . $e->getMessage());
        return;
    }

    $projectId = 'anri-5e06f'; 
    $fcmApiUrl = 'https://fcm.googleapis.com/v1/projects/' . $projectId . '/messages:send';

    // 3. Buat Payload.
    $message = [
        'message' => [
            'token' => $token,
            'notification' => ['title' => $title, 'body' => $body],
            'data' => ['click_action' => 'FLUTTER_NOTIFICATION_CLICK', 'ticket_id' => $ticket_id]
        ]
    ];

    // 4. Kirim dengan cURL.
    $ch = curl_init($fcmApiUrl);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . $accessToken, 'Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $response_body = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);
    
    if ($http_code != 200 || $curl_error) {
        error_log("FCM Send Error: HTTP $http_code | cURL Error: $curl_error | Response: $response_body");
    }
}

// Panggil fungsi utama untuk mengirim notifikasi.
send_fcm_notification_final($conn, $user_id, $title, $body, $ticket_id);
?>