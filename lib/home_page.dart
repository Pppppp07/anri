import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anri/pages/login_page.dart';

// Dummy data untuk Problem Requests
class ProblemRequest {
  final String id;
  final String title;
  final String category;
  final String status;
  final String division;
  final String priority;
  final String lastUpdate;

  ProblemRequest({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.division,
    required this.priority,
    required this.lastUpdate,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // === STATE MANAGEMENT BARU ===
  int _selectedIndex = 0;
  String _selectedFilter = 'Semua Keluhan';

  // Daftar keluhan tidak berubah
  final List<ProblemRequest> _allProblemRequests = [
    ProblemRequest(
      id: 'PR-001',
      title: 'Laptop butuh perbaikan software',
      category: 'Software',
      status: 'Baru',
      division: 'IT',
      priority: 'High',
      lastUpdate: 'Baru',
    ),
    ProblemRequest(
      id: 'PR-002',
      title: 'Printer Ruang A tidak berfungsi',
      category: 'Hardware',
      status: 'Diproses',
      division: 'Umum',
      priority: 'Medium',
      lastUpdate: '1 jam lalu',
    ),
    ProblemRequest(
      id: 'PR-003',
      title: 'Akses jaringan lambat',
      category: 'Jaringan',
      status: 'Selesai',
      division: 'IT',
      priority: 'High',
      lastUpdate: 'Kemarin',
    ),
    ProblemRequest(
      id: 'PR-004',
      title: 'AC Ruang Server Panas',
      category: 'Fasilitas',
      status: 'Baru',
      division: 'Fasilitas',
      priority: 'Critical',
      lastUpdate: '10 menit lalu',
    ),
    ProblemRequest(
      id: 'PR-005',
      title: 'Permintaan instalasi software baru',
      category: 'Software',
      status: 'Diproses',
      division: 'IT',
      priority: 'Medium',
      lastUpdate: '2 jam lalu',
    ),
    ProblemRequest(
      id: 'PR-006',
      title: 'Penerangan koridor lantai 2 mati',
      category: 'Listrik',
      status: 'Selesai',
      division: 'Umum',
      priority: 'Low',
      lastUpdate: '3 hari lalu',
    ),
    ProblemRequest(
      id: 'PR-007',
      title: 'Mouse kantor tidak responsif',
      category: 'Hardware',
      status: 'Baru',
      division: 'IT',
      priority: 'Medium',
      lastUpdate: '25 menit lalu',
    ),
  ];

  List<ProblemRequest> _filteredProblemRequests = [];

  @override
  void initState() {
    super.initState();
    _filterRequests();
  }

  // === FUNGSI FILTER DIMODIFIKASI ===
  void _filterRequests() {
    setState(() {
      // Filter untuk dashboard utama (tidak termasuk yang sudah selesai)
      if (_selectedFilter == 'Semua Keluhan') {
        _filteredProblemRequests = _allProblemRequests
            .where((req) => req.status != 'Selesai')
            .toList();
      } else if (_selectedFilter == 'Baru') {
        _filteredProblemRequests = _allProblemRequests
            .where((req) => req.status == 'Baru')
            .toList();
      } else if (_selectedFilter == 'Diproses') {
        _filteredProblemRequests = _allProblemRequests
            .where((req) => req.status == 'Diproses')
            .toList();
      } else if (_selectedFilter == 'Divisi IT') {
        _filteredProblemRequests = _allProblemRequests
            .where((req) => req.division == 'IT' && req.status != 'Selesai')
            .toList();
      }
    });
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Baru':
        return Colors.red.shade700;
      case 'Diproses':
        return Colors.orange.shade700;
      case 'Selesai':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Software':
        return Icons.computer;
      case 'Hardware':
        return Icons.print;
      case 'Jaringan':
        return Icons.wifi;
      case 'Fasilitas':
        return Icons.lightbulb_outline;
      case 'Listrik':
        return Icons.flash_on;
      default:
        return Icons.miscellaneous_services;
    }
  }

  // === WIDGET BUILDER BARU ===

  // Widget untuk membangun tampilan berdasarkan item navigasi yang dipilih
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardBody();
      case 1:
        return _buildHistoryBody();
      case 2:
        return _buildSettingsBody();
      default:
        return _buildDashboardBody();
    }
  }

  // Tampilan untuk Dashboard (Beranda)
  Widget _buildDashboardBody() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              _buildFilterChip('Semua Keluhan'),
              const SizedBox(width: 8),
              _buildFilterChip('Baru'),
              const SizedBox(width: 8),
              _buildFilterChip('Diproses'),
              const SizedBox(width: 8),
              _buildFilterChip('Divisi IT'),
              // Filter "Selesai" sudah dihapus dari sini
            ],
          ),
        ),
        Expanded(
          child: _filteredProblemRequests.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada keluhan aktif.',
                    style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: _filteredProblemRequests.length,
                  itemBuilder: (context, index) {
                    final request = _filteredProblemRequests[index];
                    return _buildProblemCard(request);
                  },
                ),
        ),
      ],
    );
  }

  // Tampilan untuk Riwayat
  Widget _buildHistoryBody() {
    final completedRequests = _allProblemRequests
        .where((req) => req.status == 'Selesai')
        .toList();

    return completedRequests.isEmpty
        ? const Center(
            child: Text(
              'Tidak ada riwayat keluhan.',
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 18.0,
            ),
            itemCount: completedRequests.length,
            itemBuilder: (context, index) {
              final request = completedRequests[index];
              return _buildProblemCard(request);
            },
          );
  }

  // Tampilan untuk Pengaturan (Placeholder)
  Widget _buildSettingsBody() {
    return const Center(
      child: Text(
        'Halaman Pengaturan',
        style: TextStyle(fontSize: 22, color: Colors.blueGrey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: Text(
          _selectedIndex == 0
              ? 'ANRI Helpdesk Dashboard'
              : (_selectedIndex == 1 ? 'Riwayat Keluhan' : 'Pengaturan'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifikasi',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profil',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
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
        ),
        child: _buildBody(), // Memanggil builder dinamis
      ),
      // === FLOATING ACTION BUTTON DIHILANGKAN ===
      // floatingActionButton: FloatingActionButton(...)

      // === BOTTOM NAVIGATION BAR DIMODIFIKASI ===
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  // Widget untuk Chip Filter
  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _filterRequests();
        });
      },
      selectedColor: Colors.blue.shade100,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade400,
        width: 1.5,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      elevation: isSelected ? 2 : 0,
      shadowColor: Colors.blue.shade50,
    );
  }

  // Widget untuk Kartu Laporan (dibuat jadi method agar bisa dipakai ulang)
  Widget _buildProblemCard(ProblemRequest request) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(request: request),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    request.id,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request.status,
                      style: TextStyle(
                        color: _getStatusColor(request.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(request.category),
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${request.division} - ${request.category}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Prioritas: ${request.priority}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    request.lastUpdate,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
