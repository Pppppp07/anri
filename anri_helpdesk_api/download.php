<?php
// Skrip ini TIDAK memerlukan otentikasi karena URL-nya sendiri sudah acak dan aman.

// 1. Ambil nama file yang diminta dari parameter URL.
// basename() digunakan untuk keamanan, mencegah upaya mengakses direktori lain.
$file_name = isset($_GET['file']) ? basename($_GET['file']) : '';

if (empty($file_name)) {
    http_response_code(400);
    die('Error: Nama file tidak spesifik.');
}

$file_path = $_SERVER['DOCUMENT_ROOT'] . '/hesk/attachments/' . $file_name;


// --- BAGIAN UNTUK VERIFIKASI (Jika masih gagal) ---
// Jika setelah ini masih gagal, hapus tanda komentar (//) pada 2 baris di bawah ini
// untuk melihat path lengkap yang coba diakses oleh skrip.
// echo "Mencari file di path: " . $file_path;
// exit();
// ----------------------------------------------------


// 3. Periksa apakah file benar-benar ada di path tersebut.
if (file_exists($file_path)) {

    // 4. Tentukan tipe konten file (MIME type) agar browser tahu cara menanganinya.
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime_type = finfo_file($finfo, $file_path);
    finfo_close($finfo);

    if (!$mime_type) {
        $mime_type = 'application/octet-stream';
    }

    // 5. Siapkan dan kirim header HTTP untuk file.
    header('Content-Type: ' . $mime_type);
    header('Content-Disposition: inline; filename="' . basename($file_path) . '"');
    header('Content-Length: ' . filesize($file_path));
    header('Cache-Control: private');
    header('Pragma: private');
    header('Expires: 0');
    
    ob_clean();
    flush();

    // 6. Baca dan kirim isi file ke browser.
    readfile($file_path);
    exit();

} else {
    // Jika file tidak ditemukan, kirim error 404.
    http_response_code(404);
    die('Error: File tidak ditemukan di server.');
}
?>