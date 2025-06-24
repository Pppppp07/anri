<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'koneksi.php';

header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

$users = [];
// Ambil semua pengguna yang bukan admin dengan ID 9999 (jika ada)
$sql = "SELECT `name` FROM `hesk_users` WHERE `id` != 9999 ORDER BY `name` ASC";
$result = mysqli_query($conn, $sql);

if ($result) {
    // Selalu tambahkan 'Unassigned' sebagai opsi pertama
    $users[] = 'Unassigned';
    while ($row = mysqli_fetch_assoc($result)) {
        $users[] = $row['name'];
    }
    echo json_encode(['success' => true, 'data' => $users]);
} else {
    echo json_encode(['success' => false, 'message' => 'Gagal mengambil data pengguna.']);
}

mysqli_close($conn);
?>