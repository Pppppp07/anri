import 'package:flutter/material.dart';
import 'package:anri/home_page.dart'; // Import untuk mengakses kelas ProblemRequest

// Widget untuk layar detail tiket
class TicketDetailScreen extends StatefulWidget {
  final ProblemRequest request; // Menerima data laporan yang dipilih

  const TicketDetailScreen({super.key, required this.request});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  // --- STATE MANAGEMENT ---
  late String _selectedStatus;
  late String _selectedPriority;
  late String _selectedCategory;
  late String _assignedTo;
  late bool _isResolved;

  // Opsi untuk dropdown
  final List<String> _statusOptions = [
    'New',
    'Waiting Reply',
    'Replied',
    'On Hold',
    'Resolved',
  ];
  final List<String> _priorityOptions = ['Critical', 'High', 'Medium', 'Low'];
  final List<String> _categoryOptions = [
    'Software',
    'Hardware',
    'Jaringan',
    'Fasilitas',
    'Listrik',
    'Umum',
  ];
  final List<String> _teamOptions = [
    'Agus (Tim IT)',
    'Budi (Tim Fasilitas)',
    'Citra (Support)',
  ];

  @override
  void initState() {
    super.initState();

    // Konversi status awal dari Bahasa Indonesia ke Bahasa Inggris jika perlu
    switch (widget.request.status) {
      case 'Baru':
        _selectedStatus = 'New';
        break;
      case 'Diproses':
        _selectedStatus = 'Replied'; // atau 'In Progress' jika ada di opsi baru
        break;
      case 'Selesai':
        _selectedStatus = 'Resolved';
        break;
      default:
        _selectedStatus = widget.request.status;
    }

    // Inisialisasi state berdasarkan data dari `widget.request`
    _selectedPriority = widget.request.priority;
    _selectedCategory = widget.request.category;
    _assignedTo = 'Agus (Tim IT)'; // Placeholder
    _isResolved = _selectedStatus == 'Resolved';
  }

  // --- UI HELPER METHODS ---

  // Widget untuk baris berisi label dan dropdown
  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _isResolved ? null : onChanged,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: _isResolved,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk baris informasi statis (Pelapor & Tanggal)
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Laporan'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Bagian Judul Laporan ---
              Text(
                widget.request.id, // Menggunakan data dari `request`
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.request.title, // Menggunakan data dari `request`
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const Divider(height: 24, thickness: 1),

              // --- Bagian Manajemen Tiket (Interaktif) ---
              _buildDropdownRow(
                label: 'Status:',
                value: _selectedStatus,
                items: _statusOptions,
                onChanged: (newValue) {
                  setState(() {
                    if (newValue != null) _selectedStatus = newValue;
                  });
                },
              ),

              // Tombol "Tandai Selesai"
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Tandai Selesai (Mark as Resolved)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isResolved
                      ? null
                      : () {
                          setState(() {
                            _isResolved = true;
                            _selectedStatus =
                                'Resolved'; // <--- PERBAIKAN: Ubah menjadi 'Resolved'
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Laporan ditandai sebagai Selesai!',
                              ),
                            ),
                          );
                        },
                ),
              ),
              const SizedBox(height: 12),

              _buildDropdownRow(
                label: 'Priority:',
                value: _selectedPriority,
                items: _priorityOptions,
                onChanged: (newValue) {
                  setState(() {
                    if (newValue != null) _selectedPriority = newValue;
                  });
                },
              ),
              _buildDropdownRow(
                label: 'Category:',
                value: _selectedCategory,
                items: _categoryOptions,
                onChanged: (newValue) {
                  setState(() {
                    if (newValue != null) _selectedCategory = newValue;
                  });
                },
              ),
              _buildDropdownRow(
                label: 'Assigned to:',
                value: _assignedTo,
                items: _teamOptions,
                onChanged: (newValue) {
                  setState(() {
                    if (newValue != null) _assignedTo = newValue;
                  });
                },
              ),

              const Divider(height: 32, thickness: 1),

              // --- Bagian Info Pelapor ---
              _buildInfoRow(
                Icons.person_outline,
                'Pelapor',
                'Budi Santoso',
              ), // Data statis
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'Terakhir Update',
                widget.request.lastUpdate,
              ),

              const Divider(height: 32, thickness: 1),

              // --- Bagian Deskripsi & Lampiran ---
              const Text(
                'Deskripsi Lengkap',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Laptop merk Dell milik saya tiba-tiba sangat lambat setelah update Windows terakhir. Beberapa aplikasi seperti Office dan Chrome sering not responding. Mohon bantuannya.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lampiran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.image, color: Colors.blue, size: 50),
                  SizedBox(width: 10),
                  Icon(Icons.description, color: Colors.red, size: 50),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
