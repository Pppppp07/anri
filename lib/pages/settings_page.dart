// lib/pages/settings_page.dart

import 'package:anri/providers/settings_provider.dart';
import 'package:anri/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  String _getThemeText(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
      case ThemeMode.system:
      default:
        return 'Sesuai Sistem';
    }
  }

  Future<bool> _authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Silakan otentikasi untuk mengubah pengaturan keamanan',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Error otentikasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error otentikasi: ${e.message}')),
        );
      }
      return false;
    }
    return authenticated;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        elevation: 1,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Notifikasi'),
          SwitchListTile(
            title: const Text('Aktifkan Notifikasi Push'),
            subtitle: Text(_notificationsEnabled ? 'Aktif' : 'Nonaktif'),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() => _notificationsEnabled = value);
            },
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          
          _buildSectionHeader('Tampilan & Preferensi'),
          _buildOptionTile(
            icon: Icons.brightness_6_outlined,
            title: 'Tema Aplikasi',
            currentValue: _getThemeText(themeProvider.themeMode),
            onTap: () => _showThemeDialog(themeProvider),
          ),
          _buildOptionTile(
            icon: Icons.sync_outlined,
            title: 'Interval Refresh Otomatis',
            currentValue: settingsProvider.refreshIntervalText,
            onTap: () => _showRefreshIntervalDialog(settingsProvider),
          ),
          
          _buildSectionHeader('Keamanan'),
          SwitchListTile(
            title: const Text('Kunci Aplikasi'),
            subtitle: const Text('Gunakan sidik jari atau PIN'),
            value: settingsProvider.isAppLockEnabled,
            onChanged: (bool value) async {
              bool authenticated = await _authenticate();
              if (authenticated && mounted) {
                context.read<SettingsProvider>().setAppLock(value);
              }
            },
            secondary: const Icon(Icons.fingerprint),
          ),
          
          _buildSectionHeader('Data'),
          _buildOptionTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Hapus Cache Aplikasi',
            onTap: _showClearCacheDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          // --- PERBAIKAN: Gunakan warna sekunder untuk kontras lebih baik ---
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? currentValue,
    VoidCallback? onTap,
  }) {
    return ListTile(
      // --- PERBAIKAN: Beri warna eksplisit pada ikon ---
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title),
      // --- PERBAIKAN: Ganti warna subtitle agar lebih terlihat ---
      subtitle: currentValue != null 
          ? Text(
              currentValue,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
            ) 
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
  
  void _showThemeDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Terang'),
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) context.read<ThemeProvider>().setThemeMode(value);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Gelap'),
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) context.read<ThemeProvider>().setThemeMode(value);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Sesuai Sistem'),
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) context.read<ThemeProvider>().setThemeMode(value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRefreshIntervalDialog(SettingsProvider settingsProvider) {
    final Map<String, int> intervals = {
      '15 detik': 15, '30 detik': 30, '1 menit': 60, 'Mati': 0
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Interval Refresh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: intervals.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(entry.key),
                value: entry.key,
                groupValue: settingsProvider.refreshIntervalText,
                onChanged: (value) {
                  context.read<SettingsProvider>().setRefreshInterval(entry.value);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Cache?'),
        content: const Text('Tindakan ini akan menghapus data sementara seperti preferensi tema dan pengaturan. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              context.read<ThemeProvider>().setThemeMode(ThemeMode.system);
              context.read<SettingsProvider>().setRefreshInterval(15);
              context.read<SettingsProvider>().setAppLock(false);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache berhasil dihapus! Pengaturan direset ke default.'))
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}