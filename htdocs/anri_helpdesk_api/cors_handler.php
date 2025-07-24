<?php
// File: cors_handler.php (Versi dengan Perekam Error)

// =================================================================
// --- KODE PEREKAM ERROR (WAJIB ADA DI PALING ATAS) ---
// =================================================================
// Jangan tampilkan error ke browser, ini akan merusak JSON
ini_set('display_errors', 0);
// Aktifkan pencatatan error ke dalam file
ini_set('log_errors', 1);
// Tentukan nama file log. File ini akan muncul di dalam folder 'anri_helpdesk_api'
ini_set('error_log', __DIR__ . '/api_error_log.txt');
// Pastikan SEMUA jenis error (termasuk Fatal Error) akan dicatat
error_reporting(E_ALL);
// =================================================================


// --- Kode CORS Asli Anda (Tetap Diperlukan) ---
if (php_sapi_name() !== 'cli') {

    header("Access-Control-Allow-Origin: *");

    header("Access-Control-Allow-Methods: GET, POST, OPTIONS");

    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

    if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
        http_response_code(204);
        exit();
    }
}
?>