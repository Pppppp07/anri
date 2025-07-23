<?php
/**
 * anri_config.inc.php
 *
 * File ini berisi SEMUA konfigurasi kustom untuk integrasi ANRI Helpdesk.
 * File ini aman dan tidak akan ditimpa saat Anda menyimpan pengaturan HESK.
 */

// Keamanan: Pastikan file ini tidak diakses langsung.
if (!defined('IN_SCRIPT')) {
    die('Hacking attempt...');
}


// --- PENGATURAN PATH ABSOLUT UNTUK API FCM ---
// Path ini sangat penting untuk memicu skrip notifikasi di latar belakang.
// Pastikan path ini sudah benar menunjuk ke folder API Anda.
define('ANRI_API_PATH', 'C:/xampp/htdocs/anri_helpdesk_api/');


// --- KREDENSIAL UNTUK NOTIFIKASI TELEGRAM ---
// Ganti dengan token bot dan chat ID grup Anda yang sebenarnya.
$hesk_settings['telegram_token'] = '***REMOVED-TELEGRAM-BOT-TOKEN***';
$hesk_settings['telegram_chat_id'] = '-1002828932838';

?>