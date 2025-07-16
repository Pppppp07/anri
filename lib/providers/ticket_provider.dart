import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ListState { loading, hasData, empty, error }

enum SortType { byDate, byPriority }

class TicketProvider with ChangeNotifier {
  List<Ticket> _tickets = [];
  ListState _listState = ListState.loading;
  String _errorMessage = '';
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;

  SortType _currentSortType = SortType.byDate; // Default sort

  List<Ticket> get tickets => _tickets;
  ListState get listState => _listState;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  SortType get currentSortType => _currentSortType;

  // --- [PERUBAHAN] HAPUS _priorityMap dan _sortTickets() ---
  // Peta prioritas dan fungsi _sortTickets() tidak lagi diperlukan karena sorting dilakukan oleh server.

  // --- [PERUBAHAN] Ubah toggleSort ---
  void toggleSort() {
    // Metode ini sekarang hanya mengubah state dan memberi tahu UI (untuk animasi ikon).
    // Pengambilan data akan di-handle oleh UI (_triggerSearch di home_page).
    _currentSortType = (_currentSortType == SortType.byDate)
        ? SortType.byPriority
        : SortType.byDate;
    notifyListeners();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  Future<List<Ticket>> _fetchData(Uri url, Map<String, String> headers) async {
    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        final List<dynamic> data = responseData['data'];
        return data.map((json) => Ticket.fromJson(json)).toList();
      } else {
        throw Exception(
          responseData['message'] ?? 'Gagal mengambil data tiket',
        );
      }
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Sesi Anda mungkin telah berakhir.');
    } else {
      throw Exception(
        'Gagal terhubung ke server: Status ${response.statusCode}',
      );
    }
  }

  String _getEndpoint(String assignee) {
    return assignee.isNotEmpty ? '/get_my_tickets.php' : '/get_tickets.php';
  }

  // --- [PERUBAHAN] Modifikasi _fetchPage untuk mengirim parameter sort_by ---
  Future<List<Ticket>> _fetchPage(
    int page, {
    required String status,
    required String category,
    required String searchQuery,
    required String priority,
    required String assignee,
  }) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty)
      throw Exception('Token tidak ditemukan atau sesi berakhir.');

    // Tentukan nilai parameter sort_by berdasarkan state saat ini
    final String sortByParam = _currentSortType == SortType.byPriority
        ? 'priority'
        : 'date';

    final endpoint = _getEndpoint(assignee);
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint').replace(
      queryParameters: {
        'page': page.toString(),
        'status': status,
        'category': category,
        'q': searchQuery,
        'priority': priority,
        'sort_by': sortByParam, // <-- KIRIM PARAMETER SORTING KE API
      },
    );
    return _fetchData(url, headers);
  }

  // --- [PERUBAHAN] Sederhanakan fetchTickets, hapus _sortTickets() ---
  Future<void> fetchTickets({
    required String status,
    required String category,
    required String searchQuery,
    required String priority,
    required String assignee,
    bool isRefresh = false,
    bool isBackgroundRefresh = false,
  }) async {
    if (isBackgroundRefresh) {
      try {
        List<Ticket> refreshedTickets = [];
        for (var i = 1; i <= _currentPage; i++) {
          final pageData = await _fetchPage(
            i,
            status: status,
            category: category,
            searchQuery: searchQuery,
            priority: priority,
            assignee: assignee,
          );
          refreshedTickets.addAll(pageData);
          if (pageData.length < 10) {
            _hasMore = false;
            break;
          }
        }
        _tickets = refreshedTickets;
        _listState = _tickets.isEmpty ? ListState.empty : ListState.hasData;
        notifyListeners();
      } catch (e) {
        debugPrint("Background refresh failed silently: $e");
      }
      return;
    }

    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _listState = ListState.loading;
      notifyListeners();
    }

    try {
      final newTickets = await _fetchPage(
        _currentPage,
        status: status,
        category: category,
        searchQuery: searchQuery,
        priority: priority,
        assignee: assignee,
      );
      _tickets = newTickets;
      _listState = _tickets.isEmpty ? ListState.empty : ListState.hasData;
      _hasMore = newTickets.length >= 10;
    } catch (e) {
      _errorMessage = e.toString();
      _listState = ListState.error;
    } finally {
      notifyListeners();
    }
  }

  // --- [PERUBAHAN] Sederhanakan loadMoreTickets, hapus _sortTickets() ---
  Future<void> loadMoreTickets({
    required String status,
    required String category,
    required String searchQuery,
    required String priority,
    required String assignee,
  }) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();
    _currentPage++;

    try {
      final newTickets = await _fetchPage(
        _currentPage,
        status: status,
        category: category,
        searchQuery: searchQuery,
        priority: priority,
        assignee: assignee,
      );
      _tickets.addAll(newTickets);
      _hasMore = newTickets.length >= 10;
    } catch (e) {
      _currentPage--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
