// lib/providers/app_data_provider.dart

import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppDataProvider with ChangeNotifier {
  List<String> _teamMembers = ['Unassigned'];
  // --- PERBAIKAN: _categories sekarang akan diisi secara dinamis ---
  Map<String, String> _categories = {'All': 'Semua Kategori'};
  bool _isTeamLoading = false;
  bool _isCategoriesLoading = false;

  List<String> get teamMembers => _teamMembers;
  Map<String, String> get categories => _categories;
  
  List<String> get categoryListForDropdown => _categories.entries
      .where((e) => e.key != 'All')
      .map((e) => e.value)
      .toList();
      
  bool get isTeamLoading => _isTeamLoading;

  // --- PERBAIKAN UTAMA 1: Tambahkan parameter forceRefresh ---
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    // Jika tidak dipaksa refresh dan data sudah ada, jangan panggil API lagi.
    if (!forceRefresh && (_isCategoriesLoading || _categories.length > 1)) return;

    _isCategoriesLoading = true;
    notifyListeners();

    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      _isCategoriesLoading = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/get_categories.php');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final Map<String, dynamic> data = responseData['data'];
          final Map<String, String> fetchedCategories = {'All': 'Semua Kategori'};
          
          data.forEach((key, value) {
            fetchedCategories[key] = value.toString().trim();
          });
          
          _categories = fetchedCategories;
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil daftar kategori: $e");
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  // --- PERBAIKAN UTAMA 2: Tambahkan parameter forceRefresh ---
  Future<void> fetchTeamMembers({bool forceRefresh = false}) async {
    // Jika tidak dipaksa refresh dan data sudah ada, jangan panggil API lagi.
    if (!forceRefresh && (_isTeamLoading || _teamMembers.length > 1)) return;

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
          // Pastikan 'Unassigned' ada di depan jika belum ada
          List<String> members = data.map((user) => user['name'].toString()).toList();
          if (!members.contains('Unassigned')) {
             members.insert(0, 'Unassigned');
          }
          _teamMembers = members;
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