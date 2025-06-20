import 'dart:async';
import 'dart:convert';
import 'package:anri/pages/login_page.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model data Ticket (tidak ada perubahan)
class Ticket {
  final int id;
  final String trackid;
  final String requesterName;
  final String subject;
  final DateTime creationDate;
  final DateTime lastChange;
  final String statusText;
  final String priorityText;
  final String categoryName;
  final String ownerName;
  final String lastReplierText;

  Ticket({
    required this.id,
    required this.trackid,
    required this.requesterName,
    required this.subject,
    required this.creationDate,
    required this.lastChange,
    required this.statusText,
    required this.priorityText,
    required this.categoryName,
    required this.ownerName,
    required this.lastReplierText,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      trackid: json['trackid'] ?? 'N/A',
      requesterName: json['requester_name'] ?? 'Unknown User',
      subject: json['subject'] ?? 'No Subject',
      creationDate: DateTime.parse(json['creation_date']),
      lastChange: DateTime.parse(json['lastchange']),
      statusText: json['status_text'] ?? 'Unknown',
      priorityText: json['priority_text'] ?? 'Unknown',
      categoryName: json['category_name'] ?? 'Uncategorized',
      ownerName: json['owner_name'] ?? 'Unassigned',
      lastReplierText: json['last_replier_text'] ?? '-',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _selectedCategory = 'All';
  String _selectedStatus = 'Semua';

  List<Ticket> _tickets = [];
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = false; // Defaultnya disembunyikan
  Timer? _autoRefreshTimer;

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

  final List<String> _statusFilters = [
    'Semua',
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
    _fetchInitialTickets();

    // --- PERUBAHAN: Logika FAB disesuaikan dengan permintaan ---
    // FAB akan muncul saat scroll ke bawah, dan sembunyi saat scroll ke atas.
    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      if (direction == ScrollDirection.reverse) {
        // Scroll ke bawah
        if (!_isFabVisible) setState(() => _isFabVisible = true);
      } else if (direction == ScrollDirection.forward) {
        // Scroll ke atas
        if (_isFabVisible) setState(() => _isFabVisible = false);
      }
    });

    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // --- PERUBAHAN: Logika Auto-Reload Cerdas ---
  void _startAutoRefreshTimer() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_selectedIndex == 0 && mounted) {
        // Panggil fungsi yang hanya menambah data baru, bukan reload total
        _fetchLatestTicketsInBackground();
      }
    });
  }

  /// (Fungsi Baru) Mengambil data terbaru di latar belakang dan hanya
  /// menambahkan tiket yang benar-benar baru ke atas daftar.
  Future<void> _fetchLatestTicketsInBackground() async {
    if (_isLoading || _isLoadingMore)
      return; // Jangan refresh jika sedang ada proses loading

    String statusForAPI = _selectedStatus == 'Semua' ? 'All' : _selectedStatus;
    final url = Uri.parse(
      '$baseUrl/get_tickets.php?status=$statusForAPI&category=$_selectedCategory&page=1',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && mounted) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> ticketData = responseData['data'];
          final List<Ticket> fetchedTickets = ticketData
              .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
              .toList();

          final existingTicketIds = _tickets.map((t) => t.id).toSet();
          final newUniqueTickets = fetchedTickets
              .where((t) => !existingTicketIds.contains(t.id))
              .toList();

          if (newUniqueTickets.isNotEmpty) {
            setState(() {
              _tickets.insertAll(0, newUniqueTickets);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal melakukan refresh di latar belakang: $e");
    }
  }

  /// (Manual Reload) Memuat ulang seluruh daftar tiket (untuk pull-to-refresh).
  Future<void> _fetchInitialTickets() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _tickets = [];
      _hasMore = true;
      _error = null;
    });
    await _fetchTickets(page: 1);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Memuat halaman selanjutnya saat scroll ke bawah.
  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchTickets(page: _currentPage);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  /// Fungsi utama untuk mengambil data dari API.
  Future<void> _fetchTickets({required int page}) async {
    String statusForAPI = _selectedIndex == 1
        ? 'Resolved'
        : (_selectedStatus == 'Semua' ? 'All' : _selectedStatus);

    final url = Uri.parse(
      '$baseUrl/get_tickets.php?status=$statusForAPI&category=$_selectedCategory&page=$page',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
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
            if (newTickets.length < 10) _hasMore = false;
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

  // Sisa kode (widget build, dll.) tidak ada perubahan signifikan

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

  Future<void> _logout(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedIndex == 0 && _isFabVisible
          ? FloatingActionButton.extended(
              onPressed: _showFilterBottomSheet,
              icon: const Icon(Icons.filter_list),
              label: const Text('Filter'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
              _selectedCategory = 'All';
              _selectedStatus = 'Semua';
              if (_scrollController.hasClients) _scrollController.jumpTo(0);
            });
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
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_selectedIndex == 0) {
      return Row(
        children: [
          Image.asset('assets/images/anri_logo.png', height: 36),
          const SizedBox(width: 12),
          const Text('Help Desk'),
        ],
      );
    } else if (_selectedIndex == 1) {
      return const Text('Riwayat Tiket Selesai');
    } else {
      return const Text('Pengaturan');
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    if (_selectedIndex == 2) {
      return const Center(child: Text('Halaman Pengaturan'));
    }
    if (_tickets.isEmpty) {
      return _buildEmptyState();
    }
    return _buildTicketList();
  }

  Widget _buildHeaderFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kategori',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            items: _categories.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() => _selectedCategory = newValue);
                _fetchInitialTickets();
              }
            },
          ),
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
              children: _statusFilters.map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStatus = status);
                        _fetchInitialTickets();
                      }
                    },
                    selectedColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.15),
                    labelStyle: TextStyle(
                      fontSize: 13,
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
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    bool isHomePage = _selectedIndex == 0;
    int itemCount = (isHomePage ? 1 : 0) + _tickets.length + (_hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _fetchInitialTickets,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (isHomePage && index == 0) {
            return _buildHeaderFilterBar();
          }
          final ticketIndex = isHomePage ? index - 1 : index;
          if (ticketIndex < _tickets.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildTicketCard(_tickets[ticketIndex]),
            );
          } else {
            return _buildLoadingMoreIndicator();
          }
        },
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(ticket: ticket),
            ),
          );
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

  Widget _buildLoadingMoreIndicator() {
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: _isLoadingMore
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: TextButton(
                  onPressed: _loadMoreTickets,
                  child: const Text('Muat Lebih Banyak'),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Tiket',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada tiket yang cocok dengan filter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
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

  void _showFilterBottomSheet() {
    String tempCategory = _selectedCategory;
    String tempStatus = _selectedStatus;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Tiket',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: tempCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (newValue) {
                      if (newValue != null)
                        setModalState(() => tempCategory = newValue);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tempStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _statusFilters
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (newValue) {
                      if (newValue != null)
                        setModalState(() => tempStatus = newValue);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _selectedStatus = tempStatus;
                            });
                            _fetchInitialTickets();
                            Navigator.pop(context);
                          },
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
