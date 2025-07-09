// lib/home_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:anri/models/ticket_model.dart'; // DIUBAH
import 'package:anri/pages/home/widgets/ticket_card.dart'; // BARU
import 'package:anri/pages/login_page.dart';
import 'package:anri/pages/profile_page.dart';
import 'package:anri/providers/ticket_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anri/config/api_config.dart';
import 'package:http/http.dart' as http;


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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  Timer? _autoRefreshTimer;
  List<String> _teamMembers = ['Unassigned'];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerFilterKey = GlobalKey();
  bool _isFabVisible = false;

  final Map<String, String> _categories = {
    'All': 'Semua Kategori',
    '1': 'Aplikasi Sistem Informasi', '2': 'SRIKANDI', '3': 'Layanan Kepegawaian',
    '4': 'Perangkat Lunak', '5': 'Perangkat Keras', '6': 'Jaringan Komputer',
    '7': 'Bangunan', '8': 'Mesin dan AC', '9': 'Listrik', '10': 'Kendaraan Dinas',
    '11': 'Pengembalian BMN', '12': 'Insiden Siber', '13': 'Pusat Data Nasional',
    '14': 'CCTV', '15': 'Email Dinas',
  };

  final List<String> _statusHeaderFilters = ['Semua Status', 'New', 'Waiting Reply'];
  final List<String> _statusDialogFilters = ['Semua Status', 'New', 'Waiting Reply', 'Replied', 'In Progress', 'On Hold'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSearch();
      _fetchTeamMembers();
    });

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _triggerSearch);
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

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _autoRefreshTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
  
  void _triggerSearch() {
    context.read<TicketProvider>().fetchTickets(
          status: _getStatusForAPI(),
          category: _selectedCategory,
          searchQuery: _searchController.text,
          isRefresh: true,
        );
  }

  String _getStatusForAPI() {
    if (_selectedIndex == 1) return 'Resolved';
    if (_selectedStatus == 'Semua Status') return 'All';
    return _selectedStatus;
  }
  
  // Method _fetchTeamMembers, _logout, _startAutoRefreshTimer tetap di sini karena
  // merupakan bagian dari logic halaman, bukan state tiket.
  // ... (Salin method _fetchTeamMembers, _logout, dan _startAutoRefreshTimer ke sini)
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
  
  Future<void> _fetchTeamMembers() async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty && mounted) return;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/get_users.php');
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

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    final ticketProvider = context.read<TicketProvider>();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_selectedIndex != 2 &&
          _searchController.text.isEmpty &&
          mounted &&
          ticketProvider.listState != ListState.loading &&
          !ticketProvider.isLoadingMore) {
        // Silent refresh
        ticketProvider.fetchTickets(
          status: _getStatusForAPI(),
          category: _selectedCategory,
          searchQuery: _searchController.text,
          isRefresh: true,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    const pageBackgroundDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [ Colors.white, Color(0xFFE0F2F7), Color(0xFFBBDEFB), Colors.blueAccent ],
        begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.0, 0.4, 0.7, 1.0],
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
                    child: Text('Hi, ${widget.currentUserName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
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
            setState(() { _selectedIndex = index; _selectedCategory = 'All'; _selectedStatus = 'New'; });
            if (index != 2) _triggerSearch();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
  
  // Di dalam file lib/home_page.dart

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
                child: Consumer<TicketProvider>(
                  builder: (context, provider, child) {
                    switch (provider.listState) {
                      case ListState.loading:
                        return const Center(child: CircularProgressIndicator());
                      case ListState.error:
                        return _buildErrorState(provider.errorMessage);
                      case ListState.empty:
                        return _buildEmptyState();
                      case ListState.hasData:
                        return RefreshIndicator(
                          onRefresh: () async => _triggerSearch(),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                            // DIUBAH: Tambah 1 item jika 'hasMore' true untuk tombol/spinner
                            itemCount: provider.tickets.length + (provider.hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // BARU: Logika untuk menampilkan tombol atau spinner
                              if (index == provider.tickets.length && provider.hasMore) {
                                // Jika ini adalah item terakhir & masih ada data
                                return provider.isLoadingMore
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16.0),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                                      child: Center(
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            context.read<TicketProvider>().loadMoreTickets(
                                              status: _getStatusForAPI(),
                                              category: _selectedCategory,
                                              searchQuery: _searchController.text,
                                            );
                                          },
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
                              
                              // Menampilkan kartu tiket seperti biasa
                              final ticket = provider.tickets[index];
                              return TicketCard(
                                ticket: ticket,
                                allCategories: _categories.entries.where((e) => e.key != 'All').map((e) => e.value).toList(),
                                allTeamMembers: _teamMembers,
                                currentUserName: widget.currentUserName,
                              );
                            },
                          ),
                        );
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

  // SEMUA method _buildTicketList, _buildTicketCard, dan _buildPaginationControl
  // TELAH DIHAPUS DARI SINI dan dipindahkan ke widgetnya masing-masing.

  // Sisa method build UI (seperti _buildAppBarTitle, _buildHeaderFilterBar) tetap sama.
  // ... (salin method _buildAppBarTitle, _buildHeaderFilterBar, _showFilterDialog, _buildEmptyState, _buildErrorState) ...
  Widget _buildAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
      case 1:
        return Row(
          children: [
            Image.asset('assets/images/anri_logo.png', height: 36, filterQuality: FilterQuality.high),
            const SizedBox(width: 12),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: const Text('Help Desk', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      case 2: return const SizedBox.shrink();
      default: return const Text('Help Desk');
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
                        ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _searchController.clear())
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    fillColor: Colors.white.withOpacity(0.8),
                    filled: true,
                    contentPadding: const EdgeInsets.only(left: 15),
                  ),
                  onSubmitted: (value) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.filter_list_alt, color: Theme.of(context).primaryColor, size: 28),
                onPressed: _showFilterDialog,
                tooltip: 'Filter Lanjutan',
              ),
            ],
          ),
          if (_selectedIndex == 0) ...[
            const SizedBox(height: 16),
            Text('Status', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
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
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.15),
                      backgroundColor: Colors.white.withOpacity(0.7),
                      labelStyle: TextStyle(color: isSelected ? Theme.of(context).primaryColor : Colors.black54, fontWeight: FontWeight.w500),
                      side: BorderSide(color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300),
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
    // Implementasi dialog tidak berubah
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
                        child: Text(status),
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
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                    const SizedBox(height: 8), 
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
            );
          },
        );
      },
    );
  }

   Widget _buildEmptyState() {
     // Implementasi tidak berubah
      bool isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearching ? Icons.search_off : Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(isSearching ? 'Tiket Tidak Ditemukan' : 'Tidak Ada Tiket', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Tidak ada tiket yang cocok dengan pencarian "$_searchController".'
                  : 'Belum ada tiket yang cocok dengan filter yang aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Hapus Pencarian'),
                onPressed: () => _searchController.clear(),
              ),
            ],
          ],
        ),
      ),
    );
   }

  Widget _buildErrorState(String error) {
    // Implementasi tidak berubah
      return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Oops, Terjadi Kesalahan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}