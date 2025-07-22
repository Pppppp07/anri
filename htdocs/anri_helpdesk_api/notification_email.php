<?php
/**
 * notification_service.php
 * Pusat untuk mengirim semua notifikasi email.
 */

// Gunakan Composer Autoloader
require_once __DIR__ . '/vendor/autoload.php';

// Import kelas PHPMailer
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

if (!function_exists('send_notification_email')) {
    /**
     * Fungsi untuk mengirim email notifikasi.
     *
     * @param string $recipient_email Alamat email penerima.
     * @param string $recipient_name Nama penerima.
     * @param string $subject Subjek email.
     * @param string $html_body Isi email dalam format HTML.
     * @return bool True jika berhasil, false jika gagal.
     */
    function send_notification_email($recipient_email, $recipient_name, $subject, $html_body) {
        // Muat variabel dari .env
        $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
        $dotenv->load();

        $mail = new PHPMailer(true);

        try {
            // Konfigurasi Server dari .env
            $mail->isSMTP();
            $mail->Host       = $_ENV['SMTP_HOST'];
            $mail->SMTPAuth   = true;
            $mail->Username   = $_ENV['SMTP_USER'];
            $mail->Password   = $_ENV['SMTP_PASS'];
            if (strtolower($_ENV['SMTP_ENCRYPTION']) == 'ssl') {
                $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
            } elseif (strtolower($_ENV['SMTP_ENCRYPTION']) == 'tls') {
                $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            }
            $mail->Port       = $_ENV['SMTP_PORT'];
            $mail->CharSet    = 'UTF-8';

            // Penerima dan Pengirim
            $mail->setFrom($_ENV['SMTP_USER'], 'Help Desk Mobile');
            $mail->addAddress($recipient_email, $recipient_name);

            // Konten Email
            $mail->isHTML(true);
            $mail->Subject = $subject;
            $mail->Body    = $html_body;
            // Opsi AltBody bisa ditambahkan jika perlu
            // $mail->AltBody = strip_tags($html_body);

            $mail->send();
            return true;
        } catch (Exception $e) {
            // Catat error ke log server untuk debugging
            error_log("PHPMailer Error: " . $mail->ErrorInfo);
            return false;
        }
    }
}
?>