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
import 'package:anri/config/api_config.dart';

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
  final String custom1; // Untuk Unit Kerja
  final String custom2; // Untuk No Ext/Hp

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
    required this.custom1,
    required this.custom2,
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
      custom1: json['custom1'] ?? '-',
      custom2: json['custom2'] ?? '-',
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

enum ListState { loading, error, empty, hasData }

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _selectedCategory = 'All';
  String _selectedStatus = 'New';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  Timer? _autoRefreshTimer;

  final ValueNotifier<List<Ticket>> _ticketsNotifier = ValueNotifier([]);
  final ValueNotifier<ListState> _listStateNotifier = ValueNotifier(
    ListState.loading,
  );
  final ValueNotifier<bool> _isLoadingMoreNotifier = ValueNotifier(false);

  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();
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

    return '${ApiConfig.baseUrl}/anri_helpdesk_api';
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

    _searchController.addListener(() {
      if ((_searchController.text.isEmpty && _searchQuery.isNotEmpty) ||
          (_searchController.text.isNotEmpty && _searchQuery.isEmpty)) {
        setState(() {});
      }

      _searchQuery = _searchController.text;

      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _fetchInitialTickets();
      });
    });

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final headerContext = _headerFilterKey.currentContext;
        if (headerContext != null) {
          final headerHeight = headerContext.size?.height ?? 200.0;
          if (_scrollController.offset > headerHeight) {
            if (!_isFabVisible) setState(() => _isFabVisible = true);
          } else {
            if (_isFabVisible) setState(() => _isFabVisible = false);
          }
        }
      }
    });
    _startAutoRefreshTimer();
  }

  Future<void> _fetchInitialData() async {
    // Panggil satu per satu. Jika _fetchTeamMembers gagal karena auth,
    // _fetchTickets tidak akan pernah dipanggil.
    await _fetchTeamMembers();

    // Pastikan widget masih ada di tree sebelum melanjutkan
    if (!mounted) return;

    await _fetchTickets(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _autoRefreshTimer?.cancel();
    _debounce?.cancel();
    _ticketsNotifier.dispose();
    _listStateNotifier.dispose();
    _isLoadingMoreNotifier.dispose();
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
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_currentPage == 1 &&
          _selectedIndex != 2 &&
          _searchController.text.isEmpty &&
          mounted &&
          _listStateNotifier.value != ListState.loading &&
          !_isLoadingMoreNotifier.value) {
        _silentRefreshTickets();
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

          final List<dynamic> data = responseData['data'];
          final List<String> fetchedMembers = data
              .map((user) => user['name'].toString())
              .toList();

          setState(() {
            _teamMembers = fetchedMembers.isNotEmpty
                ? fetchedMembers
                : ['Unassigned'];
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil daftar tim: $e");
      // Anda bisa menambahkan pesan error di UI jika diperlukan
      // setState(() => _error = 'Gagal memuat daftar tim.');
    }
  }

  void _triggerSearch() {
    _fetchInitialTickets();
  }

  Future<void> _fetchInitialTickets() async {
    _listStateNotifier.value = ListState.loading;
    _currentPage = 1;
    _hasMore = true;
    await _fetchTickets(page: 1);
  }

  Future<void> _loadMoreTickets() async {
    if (_isLoadingMoreNotifier.value || !_hasMore) return;
    _isLoadingMoreNotifier.value = true;
    _currentPage++;
    await _fetchTickets(page: _currentPage);
    _isLoadingMoreNotifier.value = false;
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
      '$baseUrl/get_tickets.php?status=$statusForAPI&category=$_selectedCategory&page=$page&search=${_searchController.text}',
    );

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 && mounted) {
        _logout(context, message: 'Sesi tidak valid. Silakan login kembali.');
        return;
      }
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final newTickets = (data['data'] as List)
              .map((json) => Ticket.fromJson(json))
              .toList();

          if (page == 1) {
            _ticketsNotifier.value = newTickets;
          } else {
            _ticketsNotifier.value = [..._ticketsNotifier.value, ...newTickets];
          }

          _hasMore = newTickets.length >= 10;

          if (_ticketsNotifier.value.isEmpty) {
            _listStateNotifier.value = ListState.empty;
          } else {
            _listStateNotifier.value = ListState.hasData;
          }
        } else {
          throw Exception(data['message'] ?? 'Gagal memuat data');
        }
      } else {
        throw Exception(
          'Gagal terhubung ke server (Kode: ${response.statusCode})',
        );
      }
    } catch (e) {
      _listStateNotifier.value = ListState.error;
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
    if (status == 'Semua Status') {
      return Colors.black87;
    }
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

  String _getPriorityIconPath(String priority) {
    switch (priority) {
      case 'Critical':
        return 'assets/images/label-critical.png';
      case 'High':
        return 'assets/images/label-high.png';
      case 'Medium':
        return 'assets/images/label-medium.png';
      case 'Low':
        return 'assets/images/label-low.png';
      default:
        return 'assets/images/label-medium.png';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.red.shade700;
      case 'High':
        return Colors.orange.shade800;
      case 'Medium':
        return Colors.green.shade700;
      case 'Low':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageBackgroundDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white,
          Color(0xFFE0F2F7),
          Color(0xFFBBDEFB),
          Colors.blueAccent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.4, 0.7, 1.0],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _selectedIndex == 0
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      'Hi, ${widget.currentUserName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          Container(
            decoration: _selectedIndex != 2 ? pageBackgroundDecoration : null,
            color: _selectedIndex == 2 ? Colors.grey[100] : null,
          ),
          _buildBody(),
        ],
      ),
      extendBodyBehindAppBar: true,
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
            _searchController.clear();
            _searchQuery = '';
            _selectedCategory = 'All';
            _selectedStatus = 'New';
            setState(() => _selectedIndex = index);
            if (index != 2) {
              _fetchInitialTickets();
            }
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
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
      case 1:
        return Row(
          children: [
            Image.asset(
              'assets/images/anri_logo.png',
              height: 36,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 12),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF0D47A1), // Biru tua
                  Color(0xFF1976D2), // Biru
                  Color(0xFF42A5F5), // Biru muda
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: const Text(
                'Help Desk',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      case 2:
        return const SizedBox.shrink();
      default:
        return const Text('Help Desk');
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
      case 1:
        return Padding(
          padding: EdgeInsets.only(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
          ),
          child: Column(
            children: [
              _buildHeaderFilterBar(),
              Expanded(
                child: ValueListenableBuilder<ListState>(
                  valueListenable: _listStateNotifier,
                  builder: (context, state, child) {
                    switch (state) {
                      case ListState.loading:
                        return const Center(child: CircularProgressIndicator());
                      case ListState.error:
                        return _buildErrorState(
                          'Tidak dapat terhubung. Periksa koneksi Anda.',
                        );
                      case ListState.empty:
                        return _buildEmptyState();
                      case ListState.hasData:
                        return _buildTicketList();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      case 2:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeaderFilterBar() {
    return Container(
      key: _headerFilterKey,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
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
                    fillColor: Colors.white.withOpacity(0.8),
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
          if (_selectedIndex == 0) ...[
            const SizedBox(height: 16),
            Text(
              'Status',
              style: TextStyle(
                color: Colors.grey.shade700,
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
                      backgroundColor: Colors.white.withOpacity(0.7),
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
            final buttonShape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            );

            return AlertDialog(
              title: const Text('Filter Lanjutan'),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: tempStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _statusDialogFilters.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: status == 'Semua Status'
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setDialogState(() => tempStatus = newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kategori',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: tempCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
              // ================= PERUBAHAN DI SINI =================
              actions: [
                // Menggunakan Column untuk layout vertikal yang responsif
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Tombol Terapkan
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _selectedCategory = tempCategory;
                          _selectedStatus = tempStatus;
                        });
                        _triggerSearch();
                      },
                      style: FilledButton.styleFrom(shape: buttonShape),
                      child: const Text('Terapkan'),
                    ),
                    const SizedBox(height: 8), // Jarak antar tombol
                    // Tombol Atur Ulang
                    OutlinedButton(
                      onPressed: () {
                        setDialogState(() {
                          tempStatus = 'New';
                          tempCategory = 'All';
                        });
                      },
                      style: OutlinedButton.styleFrom(shape: buttonShape),
                      child: const Text('Atur Ulang'),
                    ),
                  ],
                ),
              ],
              // ================= AKHIR PERUBAHAN =================
            );
          },
        );
      },
    );
  }

  Widget _buildTicketList() {
    return RefreshIndicator(
      onRefresh: _fetchInitialTickets,
      child: ValueListenableBuilder<List<Ticket>>(
        valueListenable: _ticketsNotifier,
        builder: (context, tickets, child) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
            itemCount: tickets.length + 1,
            itemBuilder: (context, index) {
              if (index < tickets.length) {
                return _buildTicketCard(tickets[index]);
              } else {
                return _buildPaginationControl();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    final DateFormat formatter = DateFormat('d MMM yy, HH:mm', 'id_ID');
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      clipBehavior: Clip.antiAlias,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${ticket.trackid}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ticket.statusText),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ticket.statusText.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(
                            ticket.priorityText,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              _getPriorityIconPath(ticket.priorityText),
                              height: 12,
                              width: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ticket.priorityText,
                              style: TextStyle(
                                color: _getPriorityColor(ticket.priorityText),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Baris untuk Requester/Nama
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.requesterName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Baris untuk Kategori (dengan Ikon baru)
              Row(
                children: [
                  Icon(
                    Icons.category_outlined, // Ikon baru untuk Kategori
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.categoryName, // Menampilkan nama kategori saja
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Baris untuk Unit Kerja (kembali menggunakan Ikon)
              Row(
                children: [
                  Icon(
                    Icons.business, // Ikon gedung untuk Unit Kerja
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.custom1, // Data Unit Kerja
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text(
                    'Lihat Detail Lainnya...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildDetailRow('Ditugaskan ke', ticket.ownerName),
                    const SizedBox(height: 6),
                    _buildDetailRow('Balasan Terakhir', ticket.lastReplierText),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Update Terakhir',
                      formatter.format(ticket.lastChange),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControl() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingMoreNotifier,
      builder: (context, isLoadingMore, child) {
        if (isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_hasMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: FilledButton.icon(
                onPressed: _loadMoreTickets,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Tampilkan Lebih Banyak'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 2,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState() {
    bool isSearching = _searchController.text.isNotEmpty;
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

  Future<void> _silentRefreshTickets() async {
    if (_isLoadingMoreNotifier.value) return;
    await _fetchTickets(page: 1);
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