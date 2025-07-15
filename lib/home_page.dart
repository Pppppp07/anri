// lib/home_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:anri/config/api_config.dart';
import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/error_page.dart';
import 'package:anri/pages/home/widgets/ticket_card.dart';
import 'package:anri/pages/login_page.dart';
import 'package:anri/pages/profile_page.dart';
import 'package:anri/providers/settings_provider.dart';
import 'package:anri/providers/ticket_provider.dart';
import 'package:anri/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TicketView { all, assignedToMe }

enum FabState { hidden, filter, scrollToTop }

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
  String _selectedPriority = 'All';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  Timer? _autoRefreshTimer;
  List<String> _teamMembers = ['Unassigned'];

  final ScrollController _scrollController = ScrollController();
  TicketView _currentView = TicketView.all;
  FabState _fabState = FabState.hidden;

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

  final List<String> _priorityDialogFilters = [
    'All',
    'Critical',
    'High',
    'Medium',
    'Low',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSearch();
      _fetchTeamMembers();
      _startAutoRefreshTimer();
    });

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _triggerSearch);
    });

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final direction = _scrollController.position.userScrollDirection;
      final offset = _scrollController.position.pixels;

      // Sembunyikan FAB jika sudah berada di paling atas
      if (offset < 200) {
        if (_fabState != FabState.hidden) {
          setState(() => _fabState = FabState.hidden);
        }
        return;
      }

      // Jika scroll ke bawah, ubah FAB menjadi mode Filter
      if (direction == ScrollDirection.reverse) {
        if (_fabState != FabState.filter) {
          setState(() => _fabState = FabState.filter);
        }
      }
      // Jika scroll ke atas, ubah FAB menjadi mode Scroll to Top
      else if (direction == ScrollDirection.forward) {
        if (_fabState != FabState.scrollToTop) {
          setState(() => _fabState = FabState.scrollToTop);
        }
      }
    });
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
    final String assigneeParam = _currentView == TicketView.assignedToMe
        ? widget.currentUserName
        : '';

    context.read<TicketProvider>().fetchTickets(
      status: _getStatusForAPI(),
      category: _selectedCategory,
      searchQuery: _searchController.text,
      priority: _selectedPriority,
      assignee: assigneeParam,
      isRefresh: true,
    );
  }

  String _getStatusForAPI() {
    // Prioritas #1: Jika di halaman Riwayat (index 1), selalu tampilkan yang 'Resolved'.
    if (_selectedIndex == 1) {
      return 'Resolved';
    }

    // Prioritas #2: Jika di Beranda (index 0) DAN tab 'Untuk Saya', tampilkan tiket 'Active'.
    if (_selectedIndex == 0 && _currentView == TicketView.assignedToMe) {
      return 'Active';
    }

    // Logika fallback untuk Beranda -> Semua Tiket
    if (_selectedStatus == 'Semua Status') {
      return 'All';
    }
    return _selectedStatus;
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    if (token == null) {
      // PERBAIKAN: use_build_context_synchronously
      // Tambahkan pengecekan mounted sebelum menggunakan context.
      if (mounted) {
        _logout(context, message: 'Sesi tidak valid. Silakan login kembali.');
      }
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _fetchTeamMembers() async {
    final headers = await _getAuthHeaders();
    if (headers.isEmpty || !mounted) return;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/get_users.php');
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      // PERBAIKAN: use_build_context_synchronously
      // Pindahkan pengecekan `mounted` setelah `await`
      if (!mounted) return;

      if (response.statusCode == 401) {
        _logout(context, message: 'Sesi tidak valid.');
        return;
      }
      if (response.statusCode == 200) {
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool('rememberMe') ?? false;
    final String? username = prefs.getString('user_username');

    await prefs.clear();

    if (rememberMe && username != null) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('user_username', username);
    }

    if (!mounted) return;

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

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (!mounted) return;
    final settingsProvider = context.read<SettingsProvider>();

    if (settingsProvider.refreshInterval == Duration.zero) {
      debugPrint("Auto refresh is OFF");
      return;
    }

    debugPrint(
      "Starting auto refresh timer with interval: ${settingsProvider.refreshIntervalText}",
    );
    _autoRefreshTimer = Timer.periodic(settingsProvider.refreshInterval, (
      timer,
    ) {
      if (_selectedIndex != 2 &&
          _searchController.text.isEmpty &&
          mounted &&
          context.read<TicketProvider>().listState != ListState.loading &&
          !context.read<TicketProvider>().isLoadingMore) {
        debugPrint("Auto refreshing tickets (background)...");
        final String assigneeParam = _currentView == TicketView.assignedToMe
            ? widget.currentUserName
            : '';
        context.read<TicketProvider>().fetchTickets(
          status: _getStatusForAPI(),
          category: _selectedCategory,
          searchQuery: _searchController.text,
          priority: _selectedPriority,
          assignee: assigneeParam,
          isRefresh: true,
          isBackgroundRefresh: true,
        );
      }
    });
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
        return Colors.red.shade400;
      case 'High':
        return Colors.orange.shade400;
      case 'Medium':
        return Colors.lightGreen.shade400;
      case 'Low':
        return Colors.lightBlue.shade400;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final pageBackgroundDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: isDarkMode
            ? [
                Theme.of(context).colorScheme.surface,
                // PERBAIKAN: deprecated_member_use. Menggunakan scaffoldBackgroundColor sebagai pengganti
                Theme.of(context).scaffoldBackgroundColor,
              ]
            : [
                Colors.white,
                const Color(0xFFE0F2F7),
                const Color(0xFFBBDEFB),
                Colors.blueAccent,
              ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    return Scaffold(
      // Tambahkan kondisi untuk menampilkan AppBar hanya jika bukan tab Profil
      appBar: _selectedIndex != 2
          ? AppBar(
              title: _buildAppBarTitle(),
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
            )
          : null,
      body: Stack(
        children: [
          // Hanya tampilkan background gradien jika bukan tab Profil
          if (_selectedIndex != 2)
            Container(decoration: pageBackgroundDecoration),
          _buildBody(),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: _buildFab(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (_selectedIndex != index) {
            _searchController.clear();
            setState(() {
              _selectedIndex = index;
              _selectedCategory = 'All';
              _selectedStatus = 'New';
              _currentView = TicketView.all;
              _fabState = FabState.hidden; // Ganti _isHeaderVisible dengan ini
            });
            if (index != 2) {
              _triggerSearch();
              _startAutoRefreshTimer();
            } else {
              _autoRefreshTimer?.cancel();
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

  Widget _buildFab() {
    switch (_fabState) {
      case FabState.filter:
        return FloatingActionButton(
          key: const ValueKey('filter'),
          onPressed: _showFilterDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          tooltip: 'Filter Lanjutan',
          child: const Icon(Icons.filter_list),
        );
      case FabState.scrollToTop:
        return FloatingActionButton(
          key: const ValueKey('scrollToTop'),
          onPressed: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
          tooltip: 'Kembali ke Atas',
          // Tambahkan properti warna di sini agar sama
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: const Icon(Icons.arrow_upward),
        );
      case FabState.hidden:
      default:
        // Kembalikan widget kosong agar animasi berjalan mulus
        return const SizedBox.shrink(key: ValueKey('hidden'));
    }
  }

  Widget _buildBody() {
    // Tentukan widget body berdasarkan _selectedIndex
    switch (_selectedIndex) {
      case 0:
      case 1:
        // Gunakan CustomScrollView untuk membuat semua elemen bisa scroll
        return RefreshIndicator(
          onRefresh: () async {
            // Header dianggap tersembunyi jika FAB sedang tidak dalam state 'hidden'
            if (_fabState != FabState.hidden) {
              await _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
            _triggerSearch();
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Header sebagai Sliver. Header akan ikut scroll dan menghilang.
              SliverToBoxAdapter(child: _buildHeaderFilterBar()),
              // 2. Consumer untuk daftar tiket, sekarang menggunakan SliverList
              Consumer<TicketProvider>(
                builder: (context, provider, child) {
                  switch (provider.listState) {
                    case ListState.loading:
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    case ListState.error:
                      return SliverFillRemaining(
                        child: _buildErrorState(provider.errorMessage),
                      );
                    case ListState.empty:
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      );
                    case ListState.hasData:
                      // Gunakan SliverList untuk menampilkan daftar tiket
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < provider.tickets.length) {
                              final ticket = provider.tickets[index];
                              return TicketCard(
                                // TAMBAHKAN KEY UNIK DI SINI
                                key: ValueKey(ticket.id),
                                ticket: ticket,
                                allCategories: _categories.entries
                                    .where((e) => e.key != 'All')
                                    .map((e) => e.value)
                                    .toList(),
                                allTeamMembers: _teamMembers,
                                currentUserName: widget.currentUserName,
                                onRefresh: _triggerSearch,
                              );
                            } else {
                              // Tampilkan tombol "load more" di akhir list
                              return _buildPaginationControl(provider);
                            }
                          },
                          childCount:
                              provider.tickets.length +
                              (provider.hasMore ? 1 : 0),
                        ),
                      );
                  }
                },
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

  Widget _buildAppBarTitle() {
    if (_selectedIndex == 2) {
      return const SizedBox.shrink();
    }
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
            colors: [Colors.lightBlueAccent, Colors.blue, Colors.blueAccent],
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
  }

  Widget _buildHeaderFilterBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final ticketProvider = context.watch<TicketProvider>();

    // PERBAIKAN: deprecated_member_use. Mengganti MaterialState dengan WidgetState.
    final ButtonStyle segmentedButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return Theme.of(context).colorScheme.primary;
        }
        return isDarkMode
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return Theme.of(context).colorScheme.onPrimary;
        }
        return Theme.of(context).colorScheme.primary;
      }),
      side: WidgetStateProperty.all(
        BorderSide(
          // PERBAIKAN: deprecated_member_use. Menggunakan withAlpha sebagai pengganti withOpacity.
          color: Theme.of(
            context,
          ).colorScheme.primary.withAlpha((255 * 0.5).round()),
        ),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );

    return Container(
      key: const ValueKey<int>(1),
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
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (value) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: AnimatedRotation(
                  turns: ticketProvider.currentSortType == SortType.byPriority
                      ? 0.5
                      : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.swap_vert,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                // --- UBAH BAGIAN ONPRESSED INI ---
                onPressed: () {
                  // Ambil provider-nya terlebih dahulu
                  final ticketProvider = context.read<TicketProvider>();

                  // Tentukan pesan yang akan tampil berdasarkan state saat ini
                  final message =
                      ticketProvider.currentSortType == SortType.byDate
                      ? 'Urutan diubah berdasarkan Prioritas'
                      : 'Urutan diubah berdasarkan Terbaru';

                  // Ubah state pengurutan
                  ticketProvider.toggleSort();

                  // Hapus snackbar lama (jika ada) dan tampilkan yang baru
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(message),
                        duration: const Duration(
                          seconds: 2,
                        ), // Tampil selama 2 detik
                      ),
                    );
                },
                // ---------------------------------
                tooltip: ticketProvider.currentSortType == SortType.byDate
                    ? 'Urutkan berdasarkan Prioritas'
                    : 'Urutkan berdasarkan Terbaru',
                iconSize: 28,
              ),
              IconButton(
                icon: Icon(
                  Icons.filter_list_alt,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter Lanjutan',
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TicketView>(
              style: segmentedButtonStyle,
              segments: const <ButtonSegment<TicketView>>[
                ButtonSegment<TicketView>(
                  value: TicketView.all,
                  label: Text('Semua Tiket'),
                  icon: Icon(Icons.list_alt),
                ),
                ButtonSegment<TicketView>(
                  value: TicketView.assignedToMe,
                  label: Text('Untuk Saya'),
                  icon: Icon(Icons.person),
                ),
              ],
              selected: {_currentView},
              onSelectionChanged: (Set<TicketView> newSelection) {
                setState(() {
                  _currentView = newSelection.first;
                });
                _triggerSearch();
              },
            ),
          ),

          if (_selectedIndex == 0 && _currentView == TicketView.all) ...[
            const SizedBox(height: 16),
            Text(
              'Status Cepat',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusHeaderFilters.map((status) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: _selectedStatus == status,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedStatus = status);
                          _triggerSearch();
                        }
                      },
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: _selectedStatus == status
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: _selectedStatus == status
                            ? Colors.transparent
                            // PERBAIKAN: deprecated_member_use. Menggunakan withAlpha sebagai pengganti withOpacity.
                            : Theme.of(context).colorScheme.outline.withAlpha(
                                (255 * 0.2).round(),
                              ),
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
    String tempPriority = _selectedPriority;

    Color getStatusColor(String status) {
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedIndex == 0) ...[
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                              style: status == 'Semua Status'
                                  ? null
                                  : TextStyle(
                                      color: getStatusColor(status),
                                      fontWeight: FontWeight.bold,
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
                    ],
                    Text(
                      'Prioritas',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: tempPriority,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: _priorityDialogFilters.map((priority) {
                        if (priority == 'All') {
                          return DropdownMenuItem<String>(
                            value: priority,
                            child: const Text('Semua Prioritas'),
                          );
                        }
                        return DropdownMenuItem<String>(
                          value: priority,
                          child: Row(
                            children: [
                              Image.asset(
                                _getPriorityIconPath(priority),
                                width: 16,
                                height: 16,
                                color: _getPriorityColor(priority),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                priority,
                                style: TextStyle(
                                  color: _getPriorityColor(priority),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setDialogState(() => tempPriority = newValue);
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
                        if (newValue != null) {
                          setDialogState(() => tempCategory = newValue);
                        }
                      },
                    ),
                  ],
                ),
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
                          _selectedPriority = tempPriority;
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
                          if (_selectedIndex == 0) {
                            final bool isHeaderFilterActive =
                                _statusHeaderFilters.contains(_selectedStatus);
                            tempStatus = isHeaderFilterActive
                                ? _selectedStatus
                                : 'New';
                          }
                          tempPriority = 'All';
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
    bool isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentView == TicketView.assignedToMe
                  ? Icons.person_search_outlined
                  : (isSearching ? Icons.search_off : Icons.inbox_outlined),
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _currentView == TicketView.assignedToMe
                  ? 'Tidak Ada Tiket Untuk Anda'
                  : (isSearching ? 'Tiket Tidak Ditemukan' : 'Tidak Ada Tiket'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _currentView == TicketView.assignedToMe
                  ? 'Tidak ada tiket yang saat ini ditugaskan kepada Anda dengan filter yang aktif.'
                  : isSearching
                  ? 'Tidak ada tiket yang cocok dengan pencarian "${_searchController.text}".'
                  : 'Belum ada tiket yang cocok dengan filter yang aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            if (isSearching) ...[
              const SizedBox(height: 20),
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

  Widget _buildErrorState(String rawError) {
    final errorInfo = ErrorIdentifier.from(rawError);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorInfo.userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ErrorPage(
                      message: errorInfo.userMessage,
                      referenceCode: errorInfo.referenceCode,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('Lihat Detail Error'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControl(TicketProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: FilledButton.icon(
          onPressed: () {
            final String assigneeParam = _currentView == TicketView.assignedToMe
                ? widget.currentUserName
                : '';
            context.read<TicketProvider>().loadMoreTickets(
              status: _getStatusForAPI(),
              category: _selectedCategory,
              searchQuery: _searchController.text,
              priority: _selectedPriority,
              assignee: assigneeParam,
            );
          },
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Tampilkan Lebih Banyak'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.primary,
            elevation: 1,
          ),
        ),
      ),
    );
  }
}
