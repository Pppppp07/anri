// lib/pages/home/widgets/ticket_card.dart

import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final List<String> allCategories;
  final List<String> allTeamMembers;
  final String currentUserName;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.allCategories,
    required this.allTeamMembers,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('d MMM yy, HH:mm', 'id_ID');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          // Navigasi tetap di sini karena ini adalah aksi dari kartu
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(
                ticket: ticket,
                allCategories: allCategories,
                allTeamMembers: allTeamMembers,
                currentUserName: currentUserName,
              ),
            ),
          );
          // Refresh logic akan ditangani oleh provider jika diperlukan setelah pop
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
                      _buildStatusChip(ticket.statusText),
                      const SizedBox(width: 8),
                      _buildPriorityChip(ticket.priorityText),
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
              _buildInfoRow(icon: Icons.person_outline, text: ticket.requesterName),
              const SizedBox(height: 8),
              _buildInfoRow(icon: Icons.category_outlined, text: ticket.categoryName),
              const SizedBox(height: 8),
              _buildInfoRow(icon: Icons.business, text: ticket.custom1),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text('Lihat Detail Lainnya...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildDetailRow('Ditugaskan ke', ticket.ownerName),
                    const SizedBox(height: 6),
                    _buildDetailRow('Balasan Terakhir', ticket.lastReplierText),
                    const SizedBox(height: 6),
                    _buildDetailRow('Update Terakhir', formatter.format(ticket.lastChange)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS KHUSUS UNTUK KARTU INI ---

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Image.asset(_getPriorityIconPath(priority), height: 12, width: 12),
          const SizedBox(width: 4),
          Text(
            priority,
            style: TextStyle(color: _getPriorityColor(priority), fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
     return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112,
          child: Text('$label:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
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

  // --- FUNGSI HELPER WARNA & IKON ---
  
  Color _getStatusColor(String status) {
    // ... (salin fungsi _getStatusColor dari home_page.dart)
    switch (status) {
      case 'New': return const Color(0xFFD32F2F);
      case 'Waiting Reply': return const Color(0xFFE65100);
      case 'Replied': return const Color(0xFF1976D2);
      case 'In Progress': return const Color(0xFF673AB7);
      case 'On Hold': return const Color(0xFFC2185B);
      case 'Resolved': return const Color(0xFF388E3C);
      default: return Colors.grey.shade700;
    }
  }

  String _getPriorityIconPath(String priority) {
    // ... (salin fungsi _getPriorityIconPath dari home_page.dart)
     switch (priority) {
      case 'Critical': return 'assets/images/label-critical.png';
      case 'High': return 'assets/images/label-high.png';
      case 'Medium': return 'assets/images/label-medium.png';
      case 'Low': return 'assets/images/label-low.png';
      default: return 'assets/images/label-medium.png';
    }
  }

  Color _getPriorityColor(String priority) {
    // ... (salin fungsi _getPriorityColor dari home_page.dart)
    switch (priority) {
      case 'Critical': return Colors.red.shade700;
      case 'High': return Colors.orange.shade800;
      case 'Medium': return Colors.green.shade700;
      case 'Low': return Colors.blue.shade700;
      default: return Colors.grey.shade700;
    }
  }
}