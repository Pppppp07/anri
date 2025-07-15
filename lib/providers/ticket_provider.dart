// lib/providers/ticket_provider.dart

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

  SortType _currentSortType = SortType.byDate;

  List<Ticket> get tickets => _tickets;
  ListState get listState => _listState;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  SortType get currentSortType => _currentSortType;

  final Map<String, int> _priorityMap = {
    'Low': 0,
    'Medium': 1,
    'High': 2,
    'Critical': 3,
  };

  void _sortTickets() {
    _tickets.sort((a, b) {
      switch (_currentSortType) {
        case SortType.byPriority:
          final priorityA = _priorityMap[a.priorityText] ?? -1;
          final priorityB = _priorityMap[b.priorityText] ?? -1;
          // Selalu urutkan prioritas dari tertinggi ke terendah
          return priorityB.compareTo(priorityA);
        case SortType.byDate:
        default:
          // Urutkan berdasarkan waktu perubahan terbaru
          return b.lastChange.compareTo(a.lastChange);
      }
    });
  }

  void toggleSort() {
    // Beralih antara mode pengurutan byDate dan byPriority
    if (_currentSortType == SortType.byDate) {
      _currentSortType = SortType.byPriority;
    } else {
      _currentSortType = SortType.byDate;
    }
    _sortTickets(); // Terapkan pengurutan baru
    notifyListeners();
  }

  Future<void> fetchTickets({
    required String status,
    required String category,
    required String searchQuery,
    required String priority,
    required String assignee,
    bool isRefresh = false,
    bool isBackgroundRefresh = false,
  }) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (!isBackgroundRefresh) {
      _listState = ListState.loading;
      notifyListeners();
    }

    try {
      List<Ticket> newTickets;
      if (assignee.isNotEmpty) {
        newTickets = await _fetchMyTicketsPage(
          _currentPage,
          searchQuery,
          priority,
          category,
        );
      } else {
        newTickets = await _fetchAllTicketsPage(
          _currentPage,
          status,
          category,
          searchQuery,
          priority,
        );
      }

      if (isRefresh) {
        _tickets = newTickets;
      } else {
        _tickets.addAll(newTickets);
      }

      _sortTickets();

      _listState = _tickets.isEmpty ? ListState.empty : ListState.hasData;
      _hasMore = newTickets.length == 10;
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
    required String priority,
    required String assignee,
  }) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();
    _currentPage++;

    try {
      List<Ticket> newTickets;
      if (assignee.isNotEmpty) {
        newTickets = await _fetchMyTicketsPage(
          _currentPage,
          searchQuery,
          priority,
          category,
        );
      } else {
        newTickets = await _fetchAllTicketsPage(
          _currentPage,
          status,
          category,
          searchQuery,
          priority,
        );
      }

      _tickets.addAll(newTickets);
      _sortTickets();

      _hasMore = newTickets.length == 10;
    } catch (e) {
      _currentPage--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<List<Ticket>> _fetchAllTicketsPage(
    int page,
    String status,
    String category,
    String searchQuery,
    String priority,
  ) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) throw Exception('Token tidak ditemukan');

    final url = Uri.parse('${ApiConfig.baseUrl}/get_tickets.php').replace(
      queryParameters: {
        'page': page.toString(),
        'status': status,
        'category': category,
        'q': searchQuery,
        'priority': priority,
      },
    );
    return _fetchData(url, headers);
  }

  Future<List<Ticket>> _fetchMyTicketsPage(
    int page,
    String searchQuery,
    String priority,
    String category,
  ) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) throw Exception('Token tidak ditemukan');

    final url = Uri.parse('${ApiConfig.baseUrl}/get_my_tickets.php').replace(
      queryParameters: {
        'page': page.toString(),
        'q': searchQuery,
        'priority': priority,
        'category': category,
      },
    );
    return _fetchData(url, headers);
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

  Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }
}
