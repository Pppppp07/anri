<?php
/**
 * File: anri_custom_functions.inc.php
 * Deskripsi: Berisi semua fungsi kustom untuk integrasi ANRI.
 * Versi: GABUNGAN (Logika Awal + Penerapan Robust dari V3)
 */

// Keamanan: Pastikan file ini tidak diakses langsung.
if (!defined('IN_SCRIPT')) {
    die('Hacking attempt...');
}

//================================================================================
// --- BAGIAN 1: FUNGSI-FUNGSI SPESIFIK (DIBUAT LEBIH ROBUST) ---
//================================================================================

/**
 * [FCM] Menjalankan skrip API untuk mengirim notifikasi push ke Firebase.
 * Fungsi ini sekarang menerima path sebagai parameter, bukan dari global/konstanta.
 * @param string $php_exe         Path ke php.exe di server.
 * @param string $api_path        Path ke folder API ANRI.
 * @param int    $user_id         ID Staf penerima.
 * @param string $title           Judul notifikasi.
 * @param string $body            Isi notifikasi.
 * @param int    $ticket_id       ID tiket yang relevan.
 */
function anri_send_fcm_notification($php_exe, $api_path, $user_id, $title, $body, $ticket_id) {
    // Pastikan path tidak kosong
    if (empty($php_exe) || empty($api_path)) {
        error_log("FCM Gagal: Path PHP atau API belum dikonfigurasi.");
        return;
    }

    $api_script_path = rtrim($api_path, '/') . '/send_notification.php';

    // Amankan semua argumen sebelum dimasukkan ke dalam command line
    $user_id_arg = escapeshellarg($user_id);
    $title_arg = escapeshellarg($title);
    $body_arg = escapeshellarg($body);
    $ticket_id_arg = escapeshellarg($ticket_id);

    // Buat perintah yang lengkap dan aman
    $command = "\"$php_exe\" \"$api_script_path\" $user_id_arg $title_arg $body_arg $ticket_id_arg";

    // Logging untuk debugging (dipertahankan dari kode awal)
    $hesk_log_file = HESK_PATH . 'hesk_fcm_trigger_log.txt';
    $log_message = date('Y-m-d H:i:s') . " [FCM TRIGGER] Mencoba menjalankan perintah: " . $command . "\n";
    file_put_contents($hesk_log_file, $log_message, FILE_APPEND);

    // Jalankan perintah di background
    if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
        pclose(popen("start /B \"FCM\" " . $command, "r"));
    } else {
        shell_exec($command . ' > /dev/null 2>&1 &');
    }
}

/**
 * [TELEGRAM] Mengirim notifikasi ke grup Telegram.
 * Fungsi ini sekarang menerima token dan chat_id sebagai parameter.
 * @param string $token   Token Bot Telegram.
 * @param string $chat_id ID Chat Grup Telegram.
 * @param string $message Pesan dalam format Markdown.
 */
function anri_send_telegram_notification($token, $chat_id, $message) {
    if (empty($token) || empty($chat_id)) {
        error_log("Telegram Gagal: Token atau Chat ID kosong.");
        return;
    }

    $url = "https://api.telegram.org/bot{$token}/sendMessage";
    $params = [
        'chat_id' => $chat_id,
        'text' => $message,
        'parse_mode' => 'Markdown',
    ];

    $ch = curl_init();
    // Opsi cURL dibuat lebih ringkas seperti pada V3
    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query($params),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 5
    ]);
    curl_exec($ch);
    curl_close($ch);
}


//================================================================================
// --- BAGIAN 2: FUNGSI "HUB" UTAMA (DIBUAT LEBIH ROBUST) ---
//================================================================================

/**
 * Fungsi HUB terpusat untuk mengirim SEMUA jenis notifikasi.
 * LOGIKA TETAP SAMA DENGAN KODE AWAL, NAMUN DENGAN PENERAPAN ROBUST.
 * @param mixed  $hesk_settings_param Parameter tambahan untuk mencegah 'fatal error' dari HESK.
 * @param string $event_type          Tipe event notifikasi.
 * @param array  $ticket              Data tiket.
 * @param int    $actor_id            ID staf yang memicu aksi.
 * @param string $message_content     Isi pesan (jika ada balasan).
 */
function anri_kirim_semua_notifikasi($hesk_settings_param, $event_type, $ticket, $actor_id = 0, $message_content = '') {

    // --- BLOK PERBAIKAN STABILITAS ---
    // Memuat ulang file konfigurasi secara paksa untuk memastikan data selalu benar dan
    // menghindari masalah dengan variabel global.
    require(HESK_PATH . 'hesk_settings.inc.php');
    if (file_exists(HESK_PATH . 'anri_config.inc.php')) {
        require_once(HESK_PATH . 'anri_config.inc.php');
    }
    // --- AKHIR BLOK PERBAIKAN ---

    // --- Konfigurasi Notifikasi (didefinisikan di sini, bukan di global) ---
    $php_exe_path     = 'C:\xampp\php\php.exe'; // PENTING: Sesuaikan path ini
    $anri_api_path    = defined('ANRI_API_PATH') ? ANRI_API_PATH : '';
    $telegram_token   = $hesk_settings['telegram_token'] ?? '';
    $telegram_chat_id = $hesk_settings['telegram_chat_id'] ?? '';

    // --- Variabel Umum (dibuat lebih aman dengan ?? operator) ---
    $priority_map  = array(0 => 'Critical🔥', 1 => 'High⚡', 2 => 'Medium🌊', 3 => 'Low🐌');
    $priority_text = $priority_map[$ticket['priority']] ?? 'N/A';
    $pelanggan     = $ticket['name'] ?? 'Pelanggan';
    $subjek        = $ticket['subject'] ?? 'Tanpa Subjek';
    $trackid       = $ticket['trackid'] ?? 'N/A';
    $ticket_id     = $ticket['id'] ?? 0;
    
    // --- Siapkan URL ---
    $hesk_url          = rtrim($hesk_settings['hesk_url'], '/');
    $admin_folder      = $hesk_settings['admin_dir'];
    $ticket_link_admin = "{$hesk_url}/{$admin_folder}/admin_ticket.php?track={$trackid}&Refresh=1";

    // --- Variabel untuk pesan & penerima ---
    $fcm_title           = '';
    $fcm_body            = '';
    $telegram_message    = '';
    $users_to_notify_fcm = [];

    // --- Logika untuk menentukan pesan & penerima (SAMA SEPERTI KODE AWAL) ---
    switch ($event_type) {
        case 'new_assigned':
        case 'new_unassigned':
            $is_from_admin = ($actor_id > 0);
            // Penanganan variabel custom_field dibuat lebih aman
            $unit_kerja = !empty($ticket['custom1']) ? ' (' . $ticket['custom1'] . ')' : '';

            // Pesan untuk FCM
            $fcm_title = ($event_type == 'new_assigned') ? "📩 Tiket Ditugaskan: #$trackid" : "📩 Tiket Baru: #$trackid";
            $fcm_body = "👤 $pelanggan$unit_kerja: \"$subjek\" (Prioritas: $priority_text)";

            // Pesan untuk Telegram
            $icon = $is_from_admin ? "📝" : "🔔";
            $title_tele = $is_from_admin ? "Tiket Baru Dibuat oleh Staf" : "Tiket Baru Diterima";
            $telegram_message = "$icon *$title_tele*\n\n" .
                                "👤 *Pelapor:* {$pelanggan}\n" .
                                "🏢 *Unit Kerja:* " . ($ticket['custom1'] ?: 'N/A') . "\n" . // Dibuat lebih aman
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
            // Penanganan pesan balasan dibuat lebih aman
            $clean_reply = !empty($message_content) ? substr(strip_tags($message_content), 0, 150) : '[pesan kosong]';
            $clean_reply .= (strlen($message_content) > 150 ? '...' : '');

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

    // --- EKSEKUSI PENGIRIMAN (memanggil fungsi helper yang sudah robust) ---

    // 1. Kirim Notifikasi FCM ke semua staf yang relevan
    if (!empty($fcm_title) && !empty($users_to_notify_fcm)) {
        foreach (array_unique($users_to_notify_fcm) as $user_id) {
            // Memanggil fungsi dengan parameter konfigurasi
            anri_send_fcm_notification($php_exe_path, $anri_api_path, $user_id, $fcm_title, $fcm_body, $ticket_id);
        }
    }

    // 2. Kirim Notifikasi Telegram (dikirim sekali ke grup)
    if (!empty($telegram_message)) {
        // Memanggil fungsi dengan parameter konfigurasi
        anri_send_telegram_notification($telegram_token, $telegram_chat_id, $telegram_message);
    }
}
?>