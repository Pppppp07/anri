import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Menggunakan model data 'Ticket' yang paling lengkap
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
      trackid: json['trackid'] ?? '',
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
  // Semua state dan fungsi lain tidak berubah...
  final List<Ticket> _tickets = [];
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String get baseUrl {
    if (kIsWeb) { return 'http://localhost:8080/anri_helpdesk_api'; } 
    else { return 'http://10.0.2.2:8080/anri_helpdesk_api'; }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialTickets();
  }
  
  Future<void> _fetchInitialTickets() async {
    setState(() {
      _isLoading = true;
      _tickets.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    List<Ticket> initialTickets = await _fetchTickets(page: 1);
    if (mounted) {
      setState(() {
        _tickets.addAll(initialTickets);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    final newTickets = await _fetchTickets(page: _currentPage);
    if (mounted) {
      if (newTickets.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        setState(() => _tickets.addAll(newTickets));
      }
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<Ticket>> _fetchTickets({int page = 1}) async {
    final url = Uri.parse('$baseUrl/get_tickets.php?page=$page'); // &status=All, dll. bisa ditambahkan nanti
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> ticketData = responseData['data'];
          return ticketData.map((json) => Ticket.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
      return [];
    }
  }

  // --- Helper Methods ---
  Color _getStatusColor(String status) {
    switch (status) {
      case 'New': return Colors.red.shade700;
      case 'In Progress': return const Color.fromARGB(255, 196, 85, 255);
      case 'Waiting reply': return Colors.orange.shade700;
      case 'On Hold': return Colors.purple.shade700;
      case 'Resolved': return Colors.green.shade700;
      default: return Colors.grey.shade700;
    }
  }
  
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical': return Colors.red.shade700;
      case 'High': return Colors.orange.shade800;
      case 'Medium': return Colors.green.shade600;
      case 'Low': return Colors.blue.shade600;
      default: return Colors.grey.shade700;
    }
  }

  // Build method utama
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(/* ... */),
      body: Container(
        // ... (Container gradien tidak berubah)
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchInitialTickets,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: _tickets.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _tickets.length) {
                      return _isLoadingMore
                          ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: TextButton(onPressed: _loadMoreTickets, child: const Text('Muat Lebih Banyak'))),
                            );
                    }
                    return _buildTicketCard(_tickets[index]);
                  },
                ),
              ),
      ),
    );
  }

  // --- PERUBAHAN UTAMA: DESAIN KARTU TIKET BARU ---
  Widget _buildTicketCard(Ticket ticket) {
    final DateFormat formatter = DateFormat('d MMM yyyy, HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          // Navigator.push(context, MaterialPageRoute(builder: (context) => TicketDetailScreen(ticket: ticket)));
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Baris 1: ID, Status, dan Prioritas ---
              Row(
                children: [
                  Text(
                    ticket.trackid,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ticket.statusText),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ticket.statusText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: ticket.priorityText,
                    child: Icon(Icons.flag, color: _getPriorityColor(ticket.priorityText), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // --- Baris 2: Judul Keluhan ---
              Text(
                ticket.subject,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // --- Baris 3: Detail Info ---
              _buildDetailRow('Assigned to:', ticket.ownerName),
              const SizedBox(height: 6),
              _buildDetailRow('Last Replied:', ticket.lastReplierText),
              const SizedBox(height: 6),
              _buildDetailRow('Dibuat:', formatter.format(ticket.creationDate)),
              const SizedBox(height: 6),
              _buildDetailRow('Update:', formatter.format(ticket.lastChange)),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER BARU UNTUK BARIS DETAIL ---
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}