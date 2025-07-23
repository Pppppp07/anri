// lib/providers/app_data_provider.dart

import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppDataProvider with ChangeNotifier {
  List<String> _teamMembers = ['Unassigned'];
  final Map<String, String> _categories = {
    'All': 'Semua Kategori',
    '1': 'Aplikasi Sistem Informasi', '2': 'SRIKANDI',
    '3': 'Layanan Kepegawaian', '4': 'Perangkat Lunak',
    '5': 'Perangkat Keras', '6': 'Jaringan Komputer',
    '7': 'Bangunan', '8': 'Mesin dan AC', '9': 'Listrik',
    '10': 'Kendaraan Dinas', '11': 'Pengembalian BMN',
    '12': 'Insiden Siber', '13': 'Pusat Data Nasional',
    '14': 'CCTV', '15': 'Email Dinas',
  };

  bool _isTeamLoading = false;

  List<String> get teamMembers => _teamMembers;
  Map<String, String> get categories => _categories;
  
  List<String> get categoryListForDropdown => _categories.entries
      .where((e) => e.key != 'All')
      .map((e) => e.value)
      .toList();
      
  bool get isTeamLoading => _isTeamLoading;

  Future<void> fetchTeamMembers() async {
    if (_isTeamLoading || _teamMembers.length > 1) return;

    _isTeamLoading = true;
    notifyListeners();

    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      _isTeamLoading = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/get_users.php');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          _teamMembers = data.map((user) => user['name'].toString()).toList();
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil daftar tim: $e");
      _teamMembers = ['Unassigned'];
    } finally {
      _isTeamLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }
}