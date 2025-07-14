<?php
// File ini akan menjadi satu-satunya sumber untuk pengaturan header CORS di seluruh aplikasi.

// Izinkan permintaan dari origin manapun. Untuk produksi, ganti '*' dengan domain frontend Anda.
// Contoh: header("Access-Control-Allow-Origin: https://helpdesk.anri.go.id");
header("Access-Control-Allow-Origin: *");

// Izinkan metode HTTP yang diperlukan oleh aplikasi.
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");

// Izinkan header kustom yang dikirim oleh Flutter, terutama 'Authorization' untuk token.
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

// Tangani Pre-flight Request dari browser.
// Jika metode request adalah OPTIONS, kirim header di atas dan hentikan eksekusi.
// Ini adalah "jawaban izin" yang ditunggu oleh browser.
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    // Kirim response 204 (No Content) yang berarti "izin diberikan, silakan lanjutkan".
    http_response_code(204);
    // Hentikan skrip agar tidak melanjutkan ke logika otentikasi/database.
    exit();
}
?>