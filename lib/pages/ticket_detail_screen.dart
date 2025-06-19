import 'package:flutter/material.dart';
import 'package:anri/home_page.dart'; // Import ini untuk mengakses kelas Ticket
import 'package:intl/intl.dart';

class TicketDetailScreen extends StatefulWidget {
  // --- PERBAIKAN 1: Menggunakan kelas 'Ticket' yang benar ---
  final Ticket ticket; 

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  // State untuk menyimpan perubahan pada dropdown
  late String _selectedStatus;
  late String _selectedPriority;
  late String _selectedCategory;
  late String _assignedTo;
  late bool _isResolved;

  // Opsi untuk dropdown, bisa Anda kembangkan lebih lanjut
  final List<String> _statusOptions = [
    'New', 'In Progress', 'Waiting reply', 'On Hold', 'Resolved',
  ];
  final List<String> _priorityOptions = ['Critical', 'High', 'Medium', 'Low'];
  final List<String> _categoryOptions = [
    'Software', 'Hardware', 'Jaringan', 'Fasilitas', 'Listrik', 'General',
  ];
  final List<String> _teamOptions = [
    'Unassigned', 'Budiono Siregar', 'Bachtiar Simon', 'Rojali',
  ];

  @override
  void initState() {
    super.initState();
    // --- PERBAIKAN 2: Inisialisasi state dari properti 'widget.ticket' ---
    _selectedStatus = widget.ticket.statusText;
    _selectedPriority = widget.ticket.priorityText;
    _selectedCategory = widget.ticket.categoryName;
    _assignedTo = widget.ticket.ownerName; // Mengambil data owner asli
    _isResolved = _selectedStatus == 'Resolved';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- PERBAIKAN 3: Menggunakan properti yang benar dari 'ticket' ---
        title: Text('Detail: ${widget.ticket.trackid}'),
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
                widget.ticket.categoryName,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.ticket.subject,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              ),
              const Divider(height: 24, thickness: 1),

              // --- Bagian Info Pelapor ---
              _buildInfoRow(Icons.person_outline, 'Pelapor', widget.ticket.requesterName),
              _buildInfoRow(
                Icons.person_pin_circle_outlined,
                'Ditugaskan ke',
                widget.ticket.ownerName,
              ),
              _buildInfoRow(
                Icons.reply_outlined,
                'Balasan Terakhir',
                widget.ticket.lastReplierText,
              ),
              const Divider(height: 24, thickness: 1),
              
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'Dibuat pada',
                DateFormat('d MMM<y_bin_46>, HH:mm').format(widget.ticket.creationDate),
              ),
              _buildInfoRow(
                Icons.edit_calendar_outlined,
                'Terakhir Update',
                DateFormat('d MMM<y_bin_46>, HH:mm').format(widget.ticket.lastChange),
              ),
              const Divider(height: 24, thickness: 1),

              // --- Bagian Manajemen Tiket (Interaktif) ---
              _buildDropdownRow(
                label: 'Status:',
                value: _selectedStatus,
                items: _statusOptions,
                onChanged: (newValue) {
                  setState(() {
                    if (newValue != null) {
                      _selectedStatus = newValue;
                      _isResolved = newValue == 'Resolved';
                    }
                  });
                },
              ),
              _buildDropdownRow(
                label: 'Prioritas:',
                value: _selectedPriority,
                items: _priorityOptions,
                onChanged: (newValue) => setState(() => _selectedPriority = newValue!),
              ),
              _buildDropdownRow(
                label: 'Kategori:',
                value: _selectedCategory,
                items: _categoryOptions,
                onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
              ),
              _buildDropdownRow(
                label: 'Tugaskan ke:',
                value: _assignedTo,
                items: _teamOptions,
                onChanged: (newValue) => setState(() => _assignedTo = newValue!),
              ),
              const SizedBox(height: 24),

              // Tombol untuk menyimpan perubahan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Simpan Perubahan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    // TODO: Tambahkan logika untuk mengirim update ke API
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logika simpan belum diimplementasikan.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget untuk baris dropdown
  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: _isResolved ? null : onChanged,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: _isResolved,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget untuk baris info
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          Expanded(
            child: Text(
              value, 
              style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}