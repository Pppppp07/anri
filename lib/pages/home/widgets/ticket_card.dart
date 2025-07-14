import 'package:anri/models/ticket_model.dart';
import 'package:anri/pages/ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final List<String> allCategories;
  final List<String> allTeamMembers;
  final String currentUserName;
  final VoidCallback onRefresh;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.allCategories,
    required this.allTeamMembers,
    required this.currentUserName,
    required this.onRefresh,
  });

  // --- BARU: Widget untuk menampilkan ikon penugasan ---
  Widget _buildOwnerIcon(BuildContext context) {
    // Jika tiket ditugaskan ke pengguna saat ini
    if (ticket.ownerName.toLowerCase() == currentUserName.toLowerCase() && ticket.ownerName != 'Unassigned') {
      return Tooltip(
        message: 'Ditugaskan ke Anda',
        child: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      );
    }
    // Jika tiket ditugaskan ke orang lain
    if (ticket.ownerName != 'Unassigned') {
      return Tooltip(
        message: 'Ditugaskan ke: ${ticket.ownerName}',
        child: Icon(
          Icons.group_outlined,
          color: Theme.of(context).textTheme.bodySmall?.color,
          size: 20,
        ),
      );
    }
    // Jika tidak ditugaskan (Unassigned)
    return Tooltip(
      message: 'Belum ditugaskan',
      child: Icon(
        Icons.person_add_disabled_outlined,
        color: Colors.grey.shade400,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('d MMM yy, HH:mm', 'id_ID');
    final Color idColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.lightBlue.shade300
        : Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
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
          if (result == true) {
            onRefresh();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      '#${ticket.trackid}',
                      style: TextStyle(
                        color: idColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildOwnerIcon(context), // <-- Ikon baru ditambahkan di sini
                      const SizedBox(width: 8),
                      _buildStatusChip(ticket.statusText),
                      const SizedBox(width: 8),
                      _buildPriorityChip(context, ticket.priorityText),
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
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                context: context,
                icon: Icons.person_outline,
                text: ticket.requesterName,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context: context,
                icon: Icons.category_outlined,
                text: ticket.categoryName,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context: context,
                icon: Icons.business,
                text: ticket.custom1,
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

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context, String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Image.asset(
            _getPriorityIconPath(priority),
            height: 12,
            width: 12,
            color: _getPriorityColor(priority),
          ),
          const SizedBox(width: 4),
          Text(
            priority,
            style: TextStyle(
              color: _getPriorityColor(priority),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final Color iconColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
}