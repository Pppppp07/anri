// lib/providers/ticket_provider.dart

import 'dart:async'; // Pastikan 'dart:async' diimpor
import 'dart:convert';
import 'package:anri/models/ticket_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anri/config/api_config.dart';

class TicketProvider with ChangeNotifier {
  // --- STATE ---
  List<Ticket> _tickets = [];
  ListState _listState = ListState.loading;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String _errorMessage = '';

  // --- GETTERS ---
  List<Ticket> get tickets => _tickets;
  ListState get listState => _listState;
  bool get isLoadingMore => _isLoadingMore;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  // --- LOGIC METHODS ---

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      return {}; 
    }
    return {'Authorization': 'Bearer $token'};
  }

  // BARU: Fungsi terpisah untuk mengambil satu halaman data
  // Ini membantu menghindari duplikasi kode.
  Future<List<Ticket>> _fetchPage(int page, String status, String category, String searchQuery) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      throw Exception('Sesi tidak valid. Silakan login kembali.');
    }

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/get_tickets.php?status=$status&category=$category&page=$page&search=$searchQuery',
    );
    
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data['data'] as List).map((json) => Ticket.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Gagal memuat data');
      }
    } else if (response.statusCode == 401) {
      throw Exception('Sesi tidak valid. Silakan login kembali.');
    } else {
      throw Exception('Gagal terhubung ke server (Kode: ${response.statusCode})');
    }
  }


  // DIUBAH: Logika fetchTickets dirombak total
  Future<void> fetchTickets({
    required String status,
    required String category,
    required String searchQuery,
    bool isRefresh = false,
    bool isBackgroundRefresh = false,
  }) async {

    // --- Logika untuk Refresh Latar Belakang ---
    if (isBackgroundRefresh) {
      try {
        List<Ticket> refreshedTickets = [];
        // Simpan jumlah halaman saat ini untuk di-loop
        final int pagesToRefresh = _currentPage; 
        
        // Ambil kembali semua halaman yang sudah dimuat
        for (int i = 1; i <= pagesToRefresh; i++) {
          final pageData = await _fetchPage(i, status, category, searchQuery);
          refreshedTickets.addAll(pageData);
        }
        
        // Ganti data lama dengan data yang sudah di-refresh total
        _tickets = refreshedTickets;
        // Set ulang `hasMore` berdasarkan hasil fetch halaman terakhir
        _hasMore = _tickets.length % 10 == 0 && _tickets.isNotEmpty;
        
        notifyListeners();
      } catch (e) {
        // Jika gagal, jangan ubah state, cukup cetak error di debug
        debugPrint("Background refresh failed: $e");
      }
      return; // Hentikan eksekusi setelah refresh latar belakang selesai
    }

    // --- Logika untuk Pemuatan Normal (Bukan Latar Belakang) ---
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _tickets = [];
    }

    if (!_isLoadingMore) {
      _listState = ListState.loading;
      notifyListeners();
    }

    try {
      final newTickets = await _fetchPage(_currentPage, status, category, searchQuery);
      
      if (_currentPage == 1) {
        _tickets = newTickets;
      } else {
        _tickets.addAll(newTickets);
      }

      _hasMore = newTickets.length >= 10;
      _listState = _tickets.isEmpty ? ListState.empty : ListState.hasData;

    } catch (e) {
      _errorMessage = e.toString();
      _listState = ListState.error;
    } finally {
      notifyListeners();
    }
  }


  Future<void> loadMoreTickets({
    required String status,
    required String category,
    required String searchQuery,
  }) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    _currentPage++;
    // Panggil fetchTickets, tapi ini akan jatuh ke logika pemuatan normal, bukan background
    await fetchTickets(
      status: status,
      category: category,
      searchQuery: searchQuery,
      isRefresh: false
    );

    _isLoadingMore = false;
    notifyListeners();
  }
}