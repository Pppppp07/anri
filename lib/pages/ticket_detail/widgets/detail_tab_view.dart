import 'package:anri/models/ticket_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';

class DetailTabView extends StatelessWidget {
  // --- Data & State ---
  final Ticket ticket;
  final bool isResolved;
  final bool isSaving;
  final Duration workedDuration;
  final DateTime? dueDate;
  final String selectedStatus;
  final String selectedPriority;
  final String selectedCategory;
  final String assignedTo;
  final List<String> statusOptions;
  final List<String> priorityOptions;
  final List<String> categoryOptions;
  final List<String> teamMemberOptions;

  // --- Widget & Callback ---
  final Widget timeWorkedBar;
  final Widget actionShortcuts;
  final Function(String?) onStatusChanged;
  final Function(String?) onPriorityChanged;
  final Function(String?) onCategoryChanged;
  final Function(String?) onOwnerChanged;
  final VoidCallback onSaveChanges;
  final VoidCallback onTapTimeWorked;
  final VoidCallback onTapDueDate;
  final VoidCallback onClearDueDate;

  const DetailTabView({
    super.key,
    required this.ticket,
    required this.isResolved,
    required this.isSaving,
    required this.workedDuration,
    required this.dueDate,
    required this.selectedStatus,
    required this.selectedPriority,
    required this.selectedCategory,
    required this.assignedTo,
    required this.statusOptions,
    required this.priorityOptions,
    required this.categoryOptions,
    required this.teamMemberOptions,
    required this.timeWorkedBar,
    required this.actionShortcuts,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
    required this.onOwnerChanged,
    required this.onSaveChanges,
    required this.onTapTimeWorked,
    required this.onTapDueDate,
    required this.onClearDueDate,
  });

  Widget _buildResolvedBanner(BuildContext context) {
    // Tentukan warna berdasarkan tema terang/gelap
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color successColor = isDarkMode
        ? Colors.greenAccent.shade400
        : Colors.green.shade800;
    final Color backgroundColor = isDarkMode
        ? Colors.green.withOpacity(0.25)
        : Colors.green.shade50;
    final Color borderColor = isDarkMode
        ? Colors.green.withOpacity(0.5)
        : Colors.green.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: successColor),
          const SizedBox(width: 12),
          Text(
            'Tiket ini telah diselesaikan.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: successColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isResolved) ...[
            _buildResolvedBanner(context),
            const SizedBox(height: 16), // Beri jarak ke kartu di bawahnya
          ],

          _buildTitledCard(
            context: context,
            icon: Icons.person_pin_circle_outlined,
            title: "Informasi Kontak & Status",
            child: _buildInfoCardContent(context),
          ),
          const SizedBox(height: 16),

          // KARTU DESKRIPSI
          _buildDescriptionCard(context),
          const SizedBox(height: 16),

          // KARTU DETAIL TIKET
          _buildTitledCard(
            context: context,
            icon: Icons.list_alt_outlined,
            title: "Detail Tiket",
            child: _buildTicketDetailsContent(context),
          ),

          if (!isResolved) ...[
            const SizedBox(height: 16), // Beri jarak dari kartu detail
            _buildTitledCard(
              context: context,
              icon: Icons.construction_outlined,
              title: "Properti & Tindakan",
              child: _buildTindakanContent(context),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET BUILDER ---

  Widget _buildInfoCardContent(BuildContext context) {
    return Column(
      children: [
        _buildInfoRow(
          context,
          Icons.bookmark_border,
          'Status:',
          ticket.statusText,
          statusColor: _getStatusColor(ticket.statusText),
        ),
        _buildInfoRow(
          context,
          Icons.person_outline,
          'Contact:',
          ticket.requesterName,
        ),
        _buildInfoRow(
          context,
          Icons.business_outlined,
          'Unit Kerja:',
          ticket.custom1,
        ),
        _buildInfoRow(
          context,
          Icons.phone_outlined,
          'No Ext/Hp:',
          ticket.custom2,
        ),
      ],
    );
  }

  Widget _buildTicketDetailsContent(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
    }

    return Column(
      children: [
        _buildStaticInfoRow(context, "Tracking ID:", ticket.trackid),
        _buildStaticInfoRow(
          context,
          "Created on:",
          dateFormat.format(ticket.creationDate),
        ),
        _buildStaticInfoRow(
          context,
          "Updated:",
          dateFormat.format(ticket.lastChange),
        ),
        _buildStaticInfoRow(context, "Replies:", ticket.replies.toString()),
        _buildStaticInfoRow(context, "Last replier:", ticket.lastReplierText),
        _buildEditableInfoRow(
          context,
          "Time worked:",
          formatDuration(workedDuration),
          onTap: isResolved ? null : onTapTimeWorked,
        ),
        _buildEditableInfoRow(
          context,
          "Due date:",
          dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : 'None',
          onTap: isResolved ? null : onTapDueDate,
          onClear: (isResolved || dueDate == null) ? null : onClearDueDate,
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        // DIUBAH: initiallyExpanded menjadi true agar kartu selalu terbuka
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: true,
          title: Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              const SizedBox(width: 16),
              const Text(
                "Deskripsi Permasalahan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          children: [
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              // DIUBAH: Bungkus dengan Column untuk menambahkan subjek
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARIS BARU UNTUK SUBJEK
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subject: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          ticket.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  // KONTEN PESAN YANG SUDAH ADA
                  Html(
                    data: ticket.message,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(15.0),
                        lineHeight: LineHeight.em(1.4),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTindakanContent(BuildContext context) {
    if (isResolved) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Tiket ini sudah selesai.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        timeWorkedBar,
        const SizedBox(height: 16),
        actionShortcuts,
        const Divider(height: 24),
        _buildEditorRows(context),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: isSaving
                ? const SizedBox.shrink()
                : const Text("Simpan Perubahan"),
            onPressed: isSaving ? null : onSaveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorRows(BuildContext context) {
    return Column(
      children: [
        _buildDropdownRow(
          context: context,
          label: 'Ticket status:',
          value: selectedStatus,
          items: statusOptions,
          onChanged: onStatusChanged,
          isStatus: true,
        ),
        _buildDropdownRow(
          context: context,
          label: 'Priority:',
          value: selectedPriority,
          items: priorityOptions,
          onChanged: onPriorityChanged,
          isPriority: true,
        ),
        _buildDropdownRow(
          context: context,
          label: 'Category:',
          value: selectedCategory,
          items: categoryOptions,
          onChanged: onCategoryChanged,
        ),
        _buildDropdownRow(
          context: context,
          label: 'Assigned to:',
          value: assignedTo,
          items: teamMemberOptions,
          onChanged: onOwnerChanged,
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  // GANTI SELURUH FUNGSI INI
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6.0,
      ), // Sedikit tambah padding vertikal
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // PENTING: Agar semua item rata atas
        children: [
          // Kolom 1: Ikon dan Label (Lebar tetap)
          SizedBox(
            width: 125, // Atur lebar tetap untuk kolom label
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),

          // Kolom 2: Nilai (Fleksibel)
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
              softWrap: true, // Pastikan teks bisa turun baris
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: onTap != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  if (onClear != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onClear,
                      borderRadius: BorderRadius.circular(20),
                      child: Icon(
                        Icons.clear,
                        size: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required BuildContext context,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isStatus = false,
    bool isPriority = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items.map((String item) {
                  Widget child;
                  // LOGIKA BARU UNTUK MEMILIH TAMPILAN ITEM
                  if (isStatus) {
                    child = Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _getStatusColor(item),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else if (isPriority) {
                    child = Row(
                      children: [
                        Image.asset(
                          _getPriorityIconPath(item),
                          width: 16,
                          height: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item,
                          style: TextStyle(
                            color: _getPriorityColor(item),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  } else {
                    child = Text(item, overflow: TextOverflow.ellipsis);
                  }

                  return DropdownMenuItem<String>(value: item, child: child);
                }).toList(),
                onChanged: isResolved ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitledCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
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
}
