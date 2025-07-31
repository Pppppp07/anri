# 📱 ANRI Helpdesk Mobile

Aplikasi mobile (Android) untuk staf teknis di **Arsip Nasional Republik Indonesia (ANRI)** dalam menangani tiket dukungan. Terintegrasi dengan **HESK Helpdesk**, aplikasi ini dilengkapi dengan **notifikasi real-time** melalui Firebase, Telegram, dan Email, serta sistem pelaporan terstruktur yang fleksibel.

---

## ✨ Fitur Utama

* **Manajemen Tiket**: Membuka, membalas, dan memperbarui status, prioritas, dan kategori tiket secara langsung dari ponsel.
* **Notifikasi Real-time**:

  * 🔔 Firebase: Push notification ke aplikasi Flutter.
  * 📩 Telegram: Pesan instan ke grup staf Helpdesk.
  * 📧 Email: Terkirim otomatis ke pelapor tiket.
* **Autentikasi Aman**: Login menggunakan sistem token JWT.
* **Pelacakan Waktu**: Monitor lama pengerjaan tiket.
* **Pencarian & Filter**: Temukan tiket dengan mudah berdasarkan status, prioritas, dan kata kunci.
* **Deep Link Mobile** (NOT YET UPDATED): Tautan dari Telegram membuka aplikasi langsung ke halaman tiket.

---

## ⚙️ Teknologi

| Komponen         | Teknologi                         |
| ---------------- | --------------------------------- |
| Frontend         | Flutter (v3.x)                    |
| Backend          | PHP 8.1+, HESK v3.4.6             |
| API              | RESTful API dengan Composer       |
| Database         | MySQL / MariaDB                   |
| Push Notifikasi  | Firebase Cloud Messaging          |
| Grup Notifikasi  | Telegram Bot + Group              |
| Email Notifikasi | PHPMailer + SMTP                  |
| Web Server Lokal | XAMPP / Laragon (🛠️ Development) |

---

## 📋 Prasyarat

* Flutter SDK v3.x
* Composer
* Node.js & npm
* Firebase CLI & FlutterFire CLI
* Akun Google (Firebase)
* Akun Telegram & Bot
* SMTP aktif (Gmail / Domain resmi)
* Web Server lokal seperti XAMPP 🛠️

---

## 🚀 Langkah Instalasi

### 1. Clone Proyek

```bash
git clone https://github.com/Pppppp07/anri.git
cd anri
```

---

### 2. Setup Backend (HESK + API)

#### a. Install HESK (Optional Jika belum ada HESK)

* Unduh dan instal [HESK v3.4.6](https://www.hesk.com/) ke direktori `htdocs/hesk/`.

#### b. Salin File Modifikasi

🛠️ **\[Development Only]**
Salin isi folder `anri/htdocs/hesk346/` ke dalam instalasi HESK Anda untuk menimpa file bawaan.
**File yang dimodifikasi:**

* `anri_custom_functions.inc.php`
* `submit_ticket.php`
* `reply_ticket.php`
* `admin/admin_submit_ticket.php`
* `hesk_settings.inc.php`

#### c. Konfigurasi API

🛠️ **\[Development Only]**

1. Pindahkan folder `anri_helpdesk_api/` ke dalam `htdocs/`
2. Duplikat file `.env.example` menjadi `.env` dan isi:

```dotenv
DB_HOST=
DB_NAME=
DB_USER=
DB_PASS=

SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASS=
SMTP_ENCRYPTION=

HESK_URL=http://locallhost/hesk346
```

3. Jalankan dependensi Composer:

```bash
cd anri_helpdesk_api
composer install
```

#### d. Modifikasi Struktur Database

🛠️ **\[Development Only]**

```sql
ALTER TABLE hesk_users ADD fcm_token TEXT NULL DEFAULT NULL;
ALTER TABLE hesk_tickets MODIFY priority TINYINT(1) NOT NULL DEFAULT 3;
```

---

### 3. Setup Telegram Bot

1. Buat bot di Telegram menggunakan @BotFather → dapatkan `BOT_TOKEN`
2. Buat grup dan undang bot → dapatkan `CHAT_ID` melalui:

   ```
   https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
   ```
3. Tambahkan konfigurasi ke `hesk_settings.inc.php`:

```php
$hesk_settings['telegram_token'] = 'TOKEN_BOT';
$hesk_settings['telegram_chat_id'] = 'CHAT_ID';
```

---

### 4. Integrasi Firebase FCM

#### a. Firebase Console

* Buat proyek baru → Tambahkan aplikasi Android
* Unduh `google-services.json` → Letakkan di `anri/android/app/`

#### b. Kunci Private (FCM Server)

* Unduh dari menu *Service Account*
* Simpan sebagai `service-account-key.json` di folder `anri_helpdesk_api/`

#### c. Instal CLI & Konfigurasi

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
flutter create . --platforms=android
```

#### d. Tambahkan SHA-256 Fingerprint

🐞 **\[Debugging Tip]**

```bash
cd android
./gradlew signingReport
```

Tambahkan SHA ke Firebase Console untuk `debug` dan `release`.

---

### 5. Setup Email (SMTP)

🛠️ **\[Development Only]**
Gunakan akun Gmail uji coba saat development. Untuk produksi, gunakan domain resmi ANRI.

#### a. Konfigurasi `.env`

```dotenv
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASS=
SMTP_ENCRYPTION=
```

#### b. Dependensi di `composer.json`&#x20;

```json
{
  "require": {
    "phpmailer/phpmailer": "^6.8",
    "vlucas/phpdotenv": "^5.6",
    "firebase/php-jwt": "^6.10",
    "google/apiclient": "^2.15.0"
  }
}
```

---

## 📧 Contoh Email Notifikasi

### 📤 Tiket Baru

```text
From: Help Desk <buat.testing66@gmail.com>
Subject: Your Ticket Has Been Submitted

Dear hola,

Your support ticket "tak tau" has been submitted.

Tracking ID: PR7-LBQ-Z1V2  
[View Ticket](http://locallhost/hesk346/ticket.php?track=PR7-LBQ-Z1V2&e=email)
```

### 📥 Balasan dari Staf

```text
From: Help Desk Mobile <buat.testing66@gmail.com>
Subject: Tanggapan Tiket Anda

Yth. kidul,

Staf kami telah memberikan balasan untuk tiket Anda:

Cek  
Admin melampirkan file.

[Balas Sekarang](http://locallhost/hesk346/ticket.php?track=YN4-TSB-3A8R&e=email)
```

---

## 🧪 Troubleshooting

| Masalah                    | Solusi                                                                   |
| -------------------------- | ------------------------------------------------------------------------ |
| 🔁 API 404                 | 🛠️ Pastikan `.htaccess` aktif dan `mod_rewrite` diaktifkan              |
| 🔔 Notifikasi tidak muncul | Periksa token FCM, file `service-account-key.json`, dan log PHP          |
| 📧 Email gagal terkirim    | Periksa kredensial SMTP di `.env` dan gunakan App Password Gmail         |
| ❌ Firebase CLI error       | Restart terminal setelah install `flutterfire_cli` atau `firebase-tools` |

---

## ✅ Menjalankan Aplikasi

🛠️ **\[Development Only]**

```bash
flutter run
```

Untuk produksi:

```bash
flutter build apk
```

---

## 📂 Struktur Folder Penting Flutter

```
├── anri/
│   ├── android/
│       ├──app/
│          ├──google-services.json           ← Penempatan file google-services.json 
│   ├── .env                                       ← konfigurasi Flutter (.env untuk IP API)
```

## 📂 Struktur Folder Penting Server

```
├── anri_helpdesk_api/
│   ├── .env                ← konfigurasi backend (DB, SMTP, FCM)
│   ├── composer.json       ← dependensi PHP
│   ├── service-account-key.json
│
├── hesk/
│   ├── submit_ticket.php
│   ├── reply_ticket.php
│   ├── anri_custom_functions.inc.php
│   ├── .htaccess           ← 🧪 mod_rewrite untuk REST API
```

---

## 📚 Referensi

* [HESK Helpdesk](https://www.hesk.com)
* [FlutterFire CLI](https://firebase.flutter.dev/docs/cli)
* [Telegram Bot API](https://core.telegram.org/bots/api)
* [PHPMailer](https://github.com/PHPMailer/PHPMailer)
* [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
* [ANRI HELPDESK MOBILE DEVELOPMENT](https://drive.google.com/drive/folders/10xonumW9Dgq1v4bRbI0NqJ21nR3BTyKi?usp=sharing)

---

## 📝 Lisensi

© Arsip Nasional Republik Indonesia – 2025. All rights reserved.
