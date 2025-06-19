<?php
// Header ini memberitahu browser bahwa API ini boleh diakses dari mana saja,
// dengan metode apa saja (GET, POST, etc), dan dengan header apa saja.
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Detail koneksi database Anda
$db_host = '127.0.0.1'; // atau 'localhost'
$db_user = 'root';       // username database Anda, defaultnya 'root' untuk XAMPP
$db_pass = '';           // password database Anda, defaultnya kosong untuk XAMPP
$db_name = 'hesk_db';    // nama database Anda

// Buat koneksi ke database
$conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);

// Cek koneksi
if (!$conn) {
  // Jika koneksi gagal, hentikan skrip dan tampilkan pesan error
  die("Koneksi gagal: " . mysqli_connect_error());
}

// Set karakter set ke utf8mb4 untuk mendukung karakter unicode
mysqli_set_charset($conn, "utf8mb4");
?>