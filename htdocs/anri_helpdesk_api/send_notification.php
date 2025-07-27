<?php
/**
 * File: send_notification.php (Versi Final dengan Payload Data Saja)
 * Deskripsi: Skrip ini HANYA untuk dijalankan dari command line (CLI) oleh sistem HESK
 * untuk mengirim notifikasi push FCM ke satu pengguna pada satu waktu.
 */

// Keamanan: Pastikan skrip hanya berjalan dari command line.
if (php_sapi_name() !== 'cli') {
    http_response_code(403);
    die("Akses ditolak. Skrip ini hanya bisa dijalankan dari command line.");
}

// Fungsi untuk logging yang konsisten
function log_fcm_activity($message) {
    file_put_contents(__DIR__ . '/fcm_activity_log.txt', '[' . date('Y-m-d H:i:s') . '] ' . $message . PHP_EOL, FILE_APPEND);
}

// --- Validasi Argumen ---
if ($argc < 5) {
    $error_msg = "FCM Script Error: Argumen tidak lengkap. Dibutuhkan 4 argumen (user_id, title, body, ticket_id).";
    log_fcm_activity($error_msg);
    die($error_msg . "\n");
}

// Ambil argumen dari command line
$user_id   = (int)$argv[1];
$title     = $argv[2];
$body      = $argv[3];
$ticket_id = (int)$argv[4];

// Muat semua dependensi SEBELUM memanggil file lain yang membutuhkannya.
require_once __DIR__ . '/vendor/autoload.php';

// Sekarang kita bisa memuat koneksi.php dengan aman karena Dotenv sudah tersedia.
require_once __DIR__ . '/koneksi.php'; 

log_fcm_activity("--- Memulai proses untuk User ID: {$user_id}, Tiket ID: {$ticket_id} ---");


// --- [PENAMBAHAN] Ambil Track ID dari database ---
$sql_trackid = "SELECT `trackid` FROM `hesk_tickets` WHERE `id` = ? LIMIT 1";
$stmt_trackid = mysqli_prepare($conn, $sql_trackid);
mysqli_stmt_bind_param($stmt_trackid, 'i', $ticket_id);
mysqli_stmt_execute($stmt_trackid);
$result_trackid = mysqli_stmt_get_result($stmt_trackid);
$track_id = 'N/A';
if ($row = mysqli_fetch_assoc($result_trackid)) {
    $track_id = $row['trackid'];
}
mysqli_stmt_close($stmt_trackid);
log_fcm_activity("Track ID ditemukan: {$track_id}");
// --- [AKHIR PENAMBAHAN] ---


// --- Fungsi Utama Pengiriman FCM ---
function send_fcm_notification_final(mysqli $conn, int $user_id, string $title, string $body, int $ticket_id, string $track_id) {
    
    // 1. Ambil FCM token dari database.
    $sql = "SELECT `fcm_token` FROM `hesk_users` WHERE `id` = ? AND `fcm_token` IS NOT NULL AND `fcm_token` != '' LIMIT 1";
    $stmt = mysqli_prepare($conn, $sql);
    mysqli_stmt_bind_param($stmt, 'i', $user_id);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);

    $token = '';
    if ($row = mysqli_fetch_assoc($result)) {
        $token = $row['fcm_token'];
        log_fcm_activity("Token ditemukan untuk User ID {$user_id}: " . substr($token, 0, 30) . "...");
    } else {
        mysqli_stmt_close($stmt);
        log_fcm_activity("Gagal: Tidak ada FCM token yang valid ditemukan untuk User ID {$user_id}.");
        return;
    }
    mysqli_stmt_close($stmt);

    // 2. Otentikasi dengan Google.
    try {
        $client = new Google\Client();
        $service_account_path = __DIR__ . '/service-account-key.json';
        if (!file_exists($service_account_path)) {
            throw new Exception("File service account 'service-account-key.json' tidak ditemukan.");
        }
        
        $client->setAuthConfig($service_account_path);
        $client->addScope('https://www.googleapis.com/auth/firebase.messaging');
        $client->fetchAccessTokenWithAssertion();
        $accessToken = $client->getAccessToken()['access_token'];
        log_fcm_activity("Otentikasi Google berhasil.");
    } catch (Exception $e) {
        log_fcm_activity('FCM Auth Error: ' . $e->getMessage());
        return;
    }

    $service_account_info = json_decode(file_get_contents($service_account_path), true);
    $projectId = $service_account_info['project_id'] ?? '';

    if (empty($projectId)) {
        log_fcm_activity('FCM Error: Project ID tidak ditemukan di dalam file service account.');
        return;
    }

    $fcmApiUrl = 'https://fcm.googleapis.com/v1/projects/' . $projectId . '/messages:send';

    // --- [PERUBAHAN UTAMA DI SINI] ---
    // Buat Payload Notifikasi dengan prioritas tinggi dan channel ID
    $message = [
        'message' => [
            'token' => $token,
            'data' => [
                'title' => $title,
                'body' => $body,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK', 
                'ticket_id' => (string)$ticket_id,
                'track_id' => $track_id,
            ],
'android' => [
    'priority' => 'high',
    'notification' => [
        'title'      => $title, // <-- TAMBAHKAN BARIS INI
        'body'       => $body,  // <-- TAMBAHKAN BARIS INI
        'channel_id' => 'high_importance_channel'
    ]
],
            // Opsi APNs (untuk iOS) bisa ditambahkan di sini jika perlu
            'apns' => [
                'headers' => [
                    'apns-priority' => '10', // Prioritas tinggi untuk iOS
                ],
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                        'content-available' => 1,
                    ],
                ],
            ],
        ]
    ];
    // --- [AKHIR PERUBAHAN UTAMA] ---

    log_fcm_activity("Payload dibuat: " . json_encode($message));

    // 4. Kirim request ke FCM API.
    $ch = curl_init($fcmApiUrl);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . $accessToken, 'Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);

    $response_body = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);
    
    // 5. Analisis Hasil dan Logging
    if ($curl_error) {
        log_fcm_activity("FCM Send Error (cURL): " . $curl_error);
    } elseif ($http_code != 200) {
        log_fcm_activity("FCM Send Error (HTTP Status: {$http_code}): Response: " . $response_body);
    } else {
        log_fcm_activity("SUKSES (HTTP 200): Notifikasi berhasil dikirim. Response: " . $response_body);
    }
}

// --- Panggil Fungsi Utama ---
// [PERUBAHAN] Kirimkan $track_id ke fungsi
send_fcm_notification_final($conn, $user_id, $title, $body, $ticket_id, $track_id);
log_fcm_activity("--- Proses Selesai --- \n");

// Tutup koneksi database
mysqli_close($conn);