<?php
/**
 * Mengirim notifikasi push menggunakan Firebase Cloud Messaging (FCM) API v1.
 *
 * @param string $recipient_token Token FCM perangkat penerima.
 * @param string $title Judul notifikasi.
 * @param string $body Isi pesan notifikasi.
 * @param array $data_payload Data tambahan yang ingin dikirim (untuk navigasi, dll).
 * @return bool|string Hasil dari eksekusi cURL atau false jika gagal.
 */
function send_fcm_notification_v1($recipient_token, $title, $body, $data_payload = []) {
    //
    // !!! PENTING: Pastikan nama file ini sesuai dengan file service account Anda !!!
    //
    $service_account_file = __DIR__ . '/anri-7f547-firebase-adminsdk-fbsvc-88d579704a.json';

    if (!file_exists($service_account_file)) {
        error_log("FCM Error: File service account tidak ditemukan di: " . $service_account_file);
        return false;
    }

    try {
        $service_account_info = json_decode(file_get_contents($service_account_file), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('Invalid JSON in service account file.');
        }

        $project_id = $service_account_info['project_id'];
        $private_key = $service_account_info['private_key'];
        $client_email = $service_account_info['client_email'];
    } catch (Exception $e) {
        error_log("FCM Error: Gagal mem-parsing file service account: " . $e->getMessage());
        return false;
    }

    // 1. Dapatkan Access Token dari Google OAuth 2.0
    $access_token = get_google_access_token($client_email, $private_key);

    if (!$access_token) {
        error_log("FCM Error: Gagal mendapatkan Google Access Token.");
        return false;
    }

    // 2. Siapkan Endpoint dan Payload untuk API v1
    $url = "https://fcm.googleapis.com/v1/projects/{$project_id}/messages:send";

    // Struktur payload untuk API v1 sedikit berbeda
    $message = [
        'message' => [
            'token' => $recipient_token,
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'data' => $data_payload,
            'android' => [ // Konfigurasi spesifik Android
                'priority' => 'high',
                'notification' => [
                    'sound' => 'default'
                ]
            ]
        ]
    ];

    $headers = [
        'Authorization: Bearer ' . $access_token,
        'Content-Type: application/json'
    ];

    // 3. Kirim request menggunakan cURL
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));

    $result = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    if ($result === false) {
        error_log('FCM cURL Error: ' . curl_error($ch));
    } else if ($http_code !== 200) {
        error_log('FCM HTTP Error: ' . $http_code . ' - Response: ' . $result);
    }

    curl_close($ch);

    return $result;
}

/**
 * Membuat Access Token OAuth 2.0 dari Service Account.
 *
 * @param string $client_email Email dari service account.
 * @param string $private_key Private key dari service account.
 * @return string|null Access token atau null jika gagal.
 */
function get_google_access_token($client_email, $private_key) {
    $scope = 'https://www.googleapis.com/auth/firebase.messaging';
    $token_url = 'https://oauth2.googleapis.com/token';

    $jwt_header = base64_url_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));

    $now = time();
    $jwt_payload_data = [
        'iss' => $client_email,
        'scope' => $scope,
        'aud' => $token_url,
        'exp' => $now + 3600, // Token berlaku selama 1 jam
        'iat' => $now,
    ];
    $jwt_payload = base64_url_encode(json_encode($jwt_payload_data));

    $signature_input = $jwt_header . '.' . $jwt_payload;
    openssl_sign($signature_input, $signature, $private_key, 'SHA256');
    $jwt_signature = base64_url_encode($signature);

    $jwt = $signature_input . '.' . $jwt_signature;

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $token_url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt,
    ]));

    $response = curl_exec($ch);
    curl_close($ch);

    $data = json_decode($response, true);
    return isset($data['access_token']) ? $data['access_token'] : null;
}

/**
 * Helper function untuk URL-safe Base64 encoding.
 */
function base64_url_encode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
?>