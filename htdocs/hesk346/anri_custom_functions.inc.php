<?php
/**
 * File: anri_custom_functions.inc.php
 * Deskripsi: Berisi semua fungsi kustom untuk integrasi ANRI.
 * Versi: GABUNGAN (Firebase + Telegram + Email) - Diperbaiki
 */

// Keamanan: Pastikan file ini tidak diakses langsung.
if (!defined('IN_SCRIPT')) {
    die('Hacking attempt...');
}

//================================================================================
// --- BAGIAN 1: FUNGSI-FUNGSI SPESIFIK PER PLATFORM NOTIFIKASI ---
//================================================================================

/**
 * [FCM] Menjalankan skrip API untuk mengirim notifikasi push ke Firebase.
 * @param int    $user_id   ID Staf penerima.
 * @param string $title     Judul notifikasi.
 * @param string $body      Isi notifikasi.
 * @param int    $ticket_id ID tiket yang relevan.
 */
function anri_send_fcm_notification($user_id, $title, $body, $ticket_id) {
    global $hesk_settings;

    // --- AWAL BLOK PERBAIKAN ---
    // Konfigurasi dasar
    $php_exe_path = 'C:\xampp\php\php.exe'; // PENTING: Sesuaikan dengan path di server Anda!
    
    // Pastikan konstanta ANRI_API_PATH sudah didefinisikan di hesk_settings.inc.php
    if (!defined('ANRI_API_PATH')) {
        error_log("FCM Gagal: Konstanta ANRI_API_PATH belum didefinisikan di hesk_settings.inc.php");
        return;
    }
    $api_script_path = ANRI_API_PATH . 'send_notification.php';

    // Amankan semua argumen sebelum dimasukkan ke dalam command line
    $user_id_arg = escapeshellarg($user_id);
    $title_arg = escapeshellarg($title);
    $body_arg = escapeshellarg($body);
    $ticket_id_arg = escapeshellarg($ticket_id);

    // Buat perintah yang lengkap dan aman
    $command = "\"$php_exe_path\" \"$api_script_path\" $user_id_arg $title_arg $body_arg $ticket_id_arg";
    // --- AKHIR BLOK PERBAIKAN ---


    // Logging untuk debugging (bisa dihapus jika sudah berjalan normal)
    $hesk_log_file = HESK_PATH . 'hesk_fcm_trigger_log.txt';
    $log_message = date('Y-m-d H:i:s') . " [FCM TRIGGER] Mencoba menjalankan perintah: " . $command . "\n";
    file_put_contents($hesk_log_file, $log_message, FILE_APPEND);

    // Jalankan perintah di background
    if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
        // Perintah untuk Windows
        pclose(popen("start /B \"FCM\" " . $command, "r"));
    } else {
        // Perintah untuk Linux
        shell_exec($command . ' > /dev/null 2>&1 &');
    }
}

/**
 * [TELEGRAM] Mengirim notifikasi ke grup Telegram.
 * @param string $message Pesan dalam format Markdown.
 */
function anri_send_telegram_notification($message) {
    global $hesk_settings;

    $botToken = $hesk_settings['telegram_token'] ?? '';
    $chatId   = $hesk_settings['telegram_chat_id'] ?? '';

    if (empty($botToken) || empty($chatId)) {
        // Tidak perlu error_log di sini karena sudah ada di log Apache
        return;
    }

    $url = "https://api.telegram.org/bot{$botToken}/sendMessage";
    $params = [
        'chat_id' => $chatId,
        'text' => $message,
        'parse_mode' => 'Markdown',
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($params));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    curl_exec($ch);
    curl_close($ch);
}


//================================================================================
// --- BAGIAN 2: FUNGSI "HUB" UTAMA UNTUK MENGATUR SEMUA NOTIFIKASI ---
//================================================================================

/**
 * Fungsi HUB terpusat untuk mengirim SEMUA jenis notifikasi.
 */
function anri_kirim_semua_notifikasi($event_type, $ticket, $actor_id = 0, $message_content = '') {
    global $hesk_settings;

    // --- Variabel Umum untuk Semua Platform ---
    $priority_map = array(0 => 'Critical🔥', 1 => 'High⚡', 2 => 'Medium🌊', 3 => 'Low🐌');
    $priority_text = $priority_map[$ticket['priority']] ?? 'N/A';
    $pelanggan = $ticket['name'];
    $subjek = $ticket['subject'];
    $trackid = $ticket['trackid'];
    $ticket_id = $ticket['id'];
    
    // --- Siapkan URL ---
    $hesk_url     = rtrim($hesk_settings['hesk_url'], '/');
    $admin_folder = $hesk_settings['admin_dir'];
    $ticket_link_admin = "{$hesk_url}/{$admin_folder}/admin_ticket.php?track={$trackid}&Refresh=1";

    // --- Variabel untuk pesan & penerima ---
    $fcm_title = '';
    $fcm_body = '';
    $telegram_message = '';
    $users_to_notify_fcm = [];

    // --- Logika untuk menentukan pesan & penerima ---
    switch ($event_type) {
        case 'new_assigned':
        case 'new_unassigned':
            $is_from_admin = ($actor_id > 0);
            $unit_kerja = !empty($ticket['custom1']) ? ' (' . $ticket['custom1'] . ')' : '';

            // Pesan untuk FCM
            $fcm_title = ($event_type == 'new_assigned') ? "📩 Tiket Ditugaskan: #$trackid" : "📩 Tiket Baru: #$trackid";
            $fcm_body = "👤 $pelanggan$unit_kerja: \"$subjek\" (Prioritas: $priority_text)";

            // Pesan untuk Telegram
            $icon = $is_from_admin ? "📝" : "🔔";
            $title_tele = $is_from_admin ? "Tiket Baru Dibuat oleh Staf" : "Tiket Baru Diterima";
            $telegram_message = "$icon *$title_tele*\n\n" .
                                "👤 *Pelapor:* {$pelanggan}\n" .
                                "🏢 *Unit Kerja:* " . ($ticket['custom1'] ?: 'N/A') . "\n" .
                                "✉️ *Subjek:* {$subjek}\n" .
                                "🆔 *Tracking ID:* `{$trackid}`\n\n" .
                                "[Buka & Tangani Tiket]({$ticket_link_admin})";

            // Tentukan penerima FCM
            if ($event_type == 'new_assigned' && !empty($ticket['owner']) && $ticket['owner'] != $actor_id) {
                $users_to_notify_fcm[] = $ticket['owner'];
            } else { // new_unassigned
                $res_staff = hesk_dbQuery("SELECT `id` FROM `".hesk_dbEscape($hesk_settings['db_pfix'])."users` WHERE `id` != ".intval($actor_id)." AND `notify_new_unassigned` = '1'");
                while ($staff = hesk_dbFetchAssoc($res_staff)) {
                    $users_to_notify_fcm[] = $staff['id'];
                }
            }
            break;

        case 'reply_customer':
            $clean_reply = substr(strip_tags($message_content), 0, 150) . (strlen($message_content) > 150 ? '...' : '');

            // Pesan untuk FCM
            $fcm_title = "💬 Balasan Baru di Tiket #$trackid";
            $fcm_body = "👤 $pelanggan membalas: \"$clean_reply\"";

            // Pesan untuk Telegram
            $telegram_message = "💬 *Balasan Baru dari Pelanggan*\n\n" .
                                "👤 *Dari:* {$pelanggan}\n" .
                                "✉️ *Subjek:* {$subjek}\n" .
                                "🆔 *Tracking ID:* `{$trackid}`\n\n" .
                                "[Lihat Balasan]({$ticket_link_admin})";

            // Tentukan penerima FCM
            if (!empty($ticket['owner'])) {
                $users_to_notify_fcm[] = $ticket['owner'];
            } else {
                $res_staff = hesk_dbQuery("SELECT `id` FROM `".hesk_dbEscape($hesk_settings['db_pfix'])."users` WHERE `notify_reply_unassigned` = '1'");
                while ($staff = hesk_dbFetchAssoc($res_staff)) {
                    $users_to_notify_fcm[] = $staff['id'];
                }
            }
            break;
    }

    // --- EKSEKUSI PENGIRIMAN ---

    // 1. Kirim Notifikasi FCM ke semua staf yang relevan
    if (!empty($fcm_title) && !empty($users_to_notify_fcm)) {
        foreach (array_unique($users_to_notify_fcm) as $user_id) {
            anri_send_fcm_notification($user_id, $fcm_title, $fcm_body, $ticket_id);
        }
    }

    // 2. Kirim Notifikasi Telegram (dikirim sekali ke grup)
    if (!empty($telegram_message)) {
        anri_send_telegram_notification($telegram_message);
    }
}
?>