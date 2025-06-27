import 'dart:async';
import 'dart:convert';
import 'package:anri/pages/login_page.dart';
import 'package:anri/pages/profile_page.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model data Ticket tidak berubah
class Ticket {
  final int id;
  final String trackid;
  final String requesterName;
  final String subject;
  final String message;
  final DateTime creationDate;
  final DateTime lastChange;
  final String statusText;
  final String priorityText;
  final String categoryName;
  final String ownerName;
  final String lastReplierText;
  final int replies;
  final String timeWorked;
  final DateTime? dueDate;

  Ticket({
    required this.id,
    required this.trackid,
    required this.requesterName,
    required this.subject,
    required this.message,
    required this.creationDate,
    required this.lastChange,
    required this.statusText,
    required this.priorityText,
    required this.categoryName,
    required this.ownerName,
    required this.lastReplierText,
    required this.replies,
    required this.timeWorked,
    this.dueDate,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      trackid: json['trackid'] ?? 'N/A',
      requesterName: json['requester_name'] ?? 'Unknown User',
      subject: json['subject'] ?? 'No Subject',
      message: json['message'] ?? '',
      creationDate: DateTime.parse(json['creation_date']),
      lastChange: DateTime.parse(json['lastchange']),
      statusText: json['status_text'] ?? 'Unknown',
      priorityText: json['priority_text'] ?? 'Unknown',
      categoryName: json['category_name'] ?? 'Uncategorized',
      ownerName: json['owner_name'] ?? 'Unassigned',
      lastReplierText: json['last_replier_text'] ?? '-',
      replies: json['replies'] as int? ?? 0,
      timeWorked: json['time_worked'] ?? '00:00:00',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
    );
  }
}

class HomePage extends StatefulWidget {
  final String currentUserName;
  final String authToken;

  const HomePage({
    super.key,
    required this.currentUserName,
    required this.authToken,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _selectedCategory = 'All';
  String _selectedStatus = 'New';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  List<Ticket> _tickets = [];
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  Timer? _autoRefreshTimer;
  final GlobalKey _headerFilterKey = GlobalKey();
  bool _isFabVisible = false;
  List<String> _teamMembers = ['Unassigned'];

  final Map<String, String> _categories = {
    'All': 'Semua Kategori',
    '1': 'Aplikasi Sistem Informasi',
    '2': 'SRIKANDI',
    '3': 'Layanan Kepegawaian',
    '4': 'Perangkat Lunak',
    '5': 'Perangkat Keras',
    '6': 'Jaringan Komputer',
    '7': 'Bangunan',
    '8': 'Mesin dan AC',
    '9': 'Listrik',
    '10': 'Kendaraan Dinas',
    '11': 'Pengembalian BMN',
    '12': 'Insiden Siber',
    '13': 'Pusat Data Nasional',
    '14': 'CCTV',
    '15': 'Email Dinas',
  };

  final List<String> _statusHeaderFilters = [
    'Semua Status',
    'New',
    'Waiting Reply',
  ];
  final List<String> _statusDialogFilters = [
    'Semua Status',
    'New',
    'Waiting Reply',
    'Replied',
    'In Progress',
    'On Hold',
  ];

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost/anri_helpdesk_api';
    } else {
      return 'http://10.0.2.2/anri_helpdesk_api';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    _searchController.addListener(() {
      setState(() {});
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchQuery != _searchController.text) {
          _triggerSearch();
        }
      });
    });

    _scrollController.addListener(() {
      final headerContext = _headerFilterKey.currentContext;
      if (headerContext != null) {
        final headerHeight = headerContext.size?.height ?? 200.0;
        if (_scrollController.offset > headerHeight) {
          if (!_isFabVisible) setState(() => _isFabVisible = true);
        } else {
          if (_isFabVisible) setState(() => _isFabVisible = false);
        }
      }
    });
    _startAutoRefreshTimer();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchTeamMembers(), _fetchTickets(page: 1)]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    if (token == null) {
      if (mounted) {
        _logout(context, message: 'Sesi tidak valid. Silakan login kembali.');
      }
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_selectedIndex != 2 && mounted && !_isLoading && !_isLoadingMore) {
        _fetchInitialTickets();
      }
    });
  }

  Future<void> _fetchTeamMembers() async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty && mounted) return;
    try {
      final url = Uri.parse('$baseUrl/get_users.php');
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        if (mounted) _logout(context, message: 'Sesi tidak valid.');
        return;
      }
      if (response.statusCode == 200 && mounted) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<String> fetchedMembers = List<String>.from(
            responseData['data'],
          );
          setState(() {
            _teamMembers = fetchedMembers.isNotEmpty
                ? fetchedMembers
                : ['Unassigned'];
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil daftar tim: $e");
    }
  }

  void _triggerSearch() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
    _fetchInitialTickets();
  }

  Future<void> _fetchInitialTickets() async {
    if (_tickets.isEmpty) {
      setState(() => _isLoading = true);
    }
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _error = null;
    });
    await _fetchTickets(page: 1);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchTickets(page: _currentPage);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _fetchTickets({required int page}) async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty) return;
    String statusForAPI = _selectedStatus;
    if (_selectedIndex == 1) {
      statusForAPI = 'Resolved';
    } else if (_selectedStatus == 'Semua Status') {
      statusForAPI = 'All';
    }
    final url = Uri.parse(
      '$baseUrl/get_tickets.php?status=$statusForAPI&category=$_selectedCategory&page=$page&search=$_searchQuery',
    );
    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        if (mounted) {
          _logout(
            context,
            message: 'Sesi Anda tidak valid. Silakan login kembali.',
          );
        }
        return;
      }
      if (response.statusCode == 200 && mounted) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> ticketData = responseData['data'];
          final List<Ticket> newTickets = ticketData
              .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
              .toList();
          setState(() {
            if (page == 1) {
              _tickets = newTickets;
            } else {
              _tickets.addAll(newTickets);
            }
            if (newTickets.length < 10) {
              _hasMore = false;
            }
          });
        } else {
          throw Exception(responseData['message'] ?? 'Gagal mengambil data');
        }
      } else {
        throw Exception(
          'Gagal terhubung ke server (Kode: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Tidak dapat terhubung. Periksa koneksi Anda.');
      }
    }
  }

  Future<void> _logout(BuildContext context, {String? message}) async {
    if (!mounted) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return const Color(0xFFD32F2F);
      case 'Waiting Reply':
        return const Color(0xFFE65100);
      case 'Replied':
        return const Color(0xFF1976D2);
      case 'In Progress':
        return const Color(0xFF673AB7);
      case 'On Hold':
        return const Color(0xFFC2185B);
      case 'Resolved':
        return const Color(0xFF388E3C);
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFD32F2F);
      case 'High':
        return const Color(0xFFEF6C00);
      case 'Medium':
        return const Color(0xFF689F38);
      case 'Low':
        return const Color(0xFF0288D1);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: _selectedIndex == 0
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      'Hi, ${widget.currentUserName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _buildBody(),
      floatingActionButton: _selectedIndex != 2 && _isFabVisible
          ? FloatingActionButton(
              onPressed: _showFilterDialog,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.filter_list, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (_selectedIndex != index) {
            // Reset search dan filter saat pindah tab
            _searchController.clear();
            _searchQuery = '';
            _selectedCategory = 'All';
            _selectedStatus = 'New';

            setState(() => _selectedIndex = index);

            _fetchInitialTickets();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return Row(
          children: [
            Image.asset('assets/images/anri_logo.png', height: 36),
            const SizedBox(width: 12),
            const Text('Help Desk'),
          ],
        );
      case 1:
        return const Text('Riwayat Tiket Selesai');
      case 2:
        return const Text('Profil');
      default:
        return const Text('Help Desk');
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
      case 1:
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return _buildErrorState(_error!);
        }
        return _buildTicketList();
      case 2:
        return const ProfilePage();
      default:
        return _buildTicketList();
    }
  }

  // --- FUNGSI INI DIUBAH ---
  Widget _buildHeaderFilterBar() {
    return Container(
      key: _headerFilterKey,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari tiket...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.grey.shade200,
                    filled: true,
                    contentPadding: const EdgeInsets.only(left: 15),
                  ),
                  onSubmitted: (value) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.filter_list_alt,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter Lanjutan',
              ),
            ],
          ),

          // -- PERUBAHAN DI SINI --
          // Tampilkan filter status hanya jika di halaman Beranda (_selectedIndex == 0)
          if (_selectedIndex == 0) ...[
            const SizedBox(height: 16),
            Text(
              'Status',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusHeaderFilters.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedStatus = status);
                          _triggerSearch();
                        }
                      },
                      selectedColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const Divider(height: 24),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    String tempCategory = _selectedCategory;
    String tempStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Filter Lanjutan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sembunyikan filter status di dialog jika di halaman Riwayat
                    if (_selectedIndex == 0) ...[
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: tempStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _statusDialogFilters.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setDialogState(() => tempStatus = newValue);
                          }
                        },
                      ),
                      const Divider(height: 24),
                    ],
                    Text(
                      'Kategori',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setDialogState(() => tempCategory = newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Tutup dialog dulu
                    setState(() {
                      _selectedStatus = 'New';
                      _selectedCategory = 'All';
                      _searchController.clear();
                    });
                  },
                  child: const Text('Reset'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Tutup dialog dulu
                    setState(() {
                      _selectedCategory = tempCategory;
                      _selectedStatus = tempStatus;
                    });
                    _triggerSearch();
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTicketList() {
    return RefreshIndicator(
      onRefresh: _fetchInitialTickets,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderFilterBar()),
          if (_tickets.isEmpty && !_isLoading)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index < _tickets.length) {
                    return _buildTicketCard(_tickets[index]);
                  } else {
                    return _buildPaginationControl();
                  }
                }, childCount: _tickets.length + 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    final DateFormat formatter = DateFormat('d MMM yy, HH:mm', 'id_ID');
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: () async {
          final categoryNames = _categories.entries
              .where((entry) => entry.key != 'All')
              .map((entry) => entry.value)
              .toList();
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(
                ticket: ticket,
                allCategories: categoryNames,
                allTeamMembers: _teamMembers,
                currentUserName: widget.currentUserName,
              ),
            ),
          );
          if (result == true) {
            _fetchInitialTickets();
          }
        },
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${ticket.trackid}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ticket.statusText),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ticket.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.flag,
                    color: _getPriorityColor(ticket.priorityText),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.subject,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kategori: ${ticket.categoryName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Divider(height: 24),
              _buildDetailRow('Requester', ticket.requesterName),
              const SizedBox(height: 6),
              _buildDetailRow('Assigned to', ticket.ownerName),
              const SizedBox(height: 6),
              _buildDetailRow('Last Replied', ticket.lastReplierText),
              const SizedBox(height: 6),
              _buildDetailRow('Update', formatter.format(ticket.lastChange)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControl() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: OutlinedButton(
            onPressed: _loadMoreTickets,
            child: const Text('Tampilkan Lebih Banyak'),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          '-- Akhir dari daftar --',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    bool isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.inbox_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'Tiket Tidak Ditemukan' : 'Tidak Ada Tiket',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Tidak ada tiket yang cocok dengan pencarian "$_searchQuery".'
                  : 'Belum ada tiket yang cocok dengan filter yang aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Hapus Pencarian'),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Oops, Terjadi Kesalahan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchInitialTickets,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
