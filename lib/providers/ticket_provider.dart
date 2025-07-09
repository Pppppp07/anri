// lib/providers/ticket_provider.dart

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
  
  // DIUBAH: Tambahkan getter untuk hasMore di sini
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

  Future<void> fetchTickets({
    required String status,
    required String category,
    required String searchQuery,
    bool isRefresh = false,
  }) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _tickets = [];
    }
    
    if (!_isLoadingMore) {
      _listState = ListState.loading;
      notifyListeners();
    }

    final headers = await _getAuthHeaders();
    if (headers.isEmpty) {
      _errorMessage = 'Sesi tidak valid. Silakan login kembali.';
      _listState = ListState.error;
      notifyListeners();
      return;
    }

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/get_tickets.php?status=$status&category=$category&page=$_currentPage&search=$searchQuery',
    );

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final newTickets = (data['data'] as List).map((json) => Ticket.fromJson(json)).toList();
          
          if (_currentPage == 1) {
            _tickets = newTickets;
          } else {
            _tickets.addAll(newTickets);
          }

          _hasMore = newTickets.length >= 10;
          _listState = _tickets.isEmpty ? ListState.empty : ListState.hasData;

        } else {
          throw Exception(data['message'] ?? 'Gagal memuat data');
        }
      } else if (response.statusCode == 401) {
         throw Exception('Sesi tidak valid. Silakan login kembali.');
      } else {
        throw Exception('Gagal terhubung ke server (Kode: ${response.statusCode})');
      }
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