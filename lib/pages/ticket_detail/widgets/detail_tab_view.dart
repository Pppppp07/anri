// lib/pages/ticket_detail/widgets/detail_tab_view.dart

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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitledCard(
            context: context,
            icon: Icons.person_pin_circle_outlined,
            title: "Informasi Kontak & Status",
            child: _buildInfoCardContent(),
          ),
          const SizedBox(height: 16),
          _buildTitledCard(
            context: context,
            icon: Icons.list_alt_outlined,
            title: "Detail Tiket",
            child: _buildTicketDetailsContent(),
          ),
          const SizedBox(height: 16),
          _buildDescriptionCard(context),
          const SizedBox(height: 16),
          if (!isResolved)
            _buildTitledCard(
              context: context,
              icon: Icons.construction_outlined,
              title: "Properti & Tindakan",
              child: _buildTindakanContent(context),
            ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER ---

  Widget _buildInfoCardContent() {
    return Column(
      children: [
        _buildInfoRow(Icons.bookmark_border, 'Status:', ticket.statusText, statusColor: _getStatusColor(ticket.statusText)),
        _buildInfoRow(Icons.person_outline, 'Contact:', ticket.requesterName),
        _buildInfoRow(Icons.business_outlined, 'Unit Kerja:', ticket.custom1),
        _buildInfoRow(Icons.phone_outlined, 'No Ext/Hp:', ticket.custom2),
      ],
    );
  }

  Widget _buildTicketDetailsContent() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
    }

    return Column(
      children: [
        _buildStaticInfoRow("Tracking ID:", ticket.trackid),
        _buildStaticInfoRow("Created on:", dateFormat.format(ticket.creationDate)),
        _buildStaticInfoRow("Updated:", dateFormat.format(ticket.lastChange)),
        _buildStaticInfoRow("Replies:", ticket.replies.toString()),
        _buildStaticInfoRow("Last replier:", ticket.lastReplierText),
        _buildEditableInfoRow(
          "Time worked:",
          formatDuration(workedDuration),
          onTap: isResolved ? null : onTapTimeWorked,
        ),
        _buildEditableInfoRow(
          "Due date:",
          dueDate != null ? dateFormat.format(dueDate!) : 'None',
          onTap: isResolved ? null : onTapDueDate,
          onClear: (isResolved || dueDate == null) ? null : onClearDueDate,
        ),
      ],
    );
  }
  
  Widget _buildDescriptionCard(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: false,
          title: Row(children: [
            Icon(Icons.description_outlined, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            const Text("Deskripsi Permasalahan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          ]),
          children: [
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Html(
                data: ticket.message,
                style: {"body": Style(margin: Margins.zero, padding: HtmlPaddings.zero, fontSize: FontSize(15.0), lineHeight: LineHeight.em(1.4))},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTindakanContent(BuildContext context) {
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
            icon: isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Icon(Icons.save_outlined),
            label: isSaving ? const SizedBox.shrink() : const Text("Simpan Perubahan"),
            onPressed: isSaving ? null : onSaveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEditorRows(BuildContext context) {
    return Column(
      children: [
        _buildDropdownRow(context: context, label: 'Ticket status:', value: selectedStatus, items: statusOptions, onChanged: onStatusChanged, isStatus: true),
        _buildDropdownRow(context: context, label: 'Priority:', value: selectedPriority, items: priorityOptions, onChanged: onPriorityChanged),
        _buildDropdownRow(context: context, label: 'Category:', value: selectedCategory, items: categoryOptions, onChanged: onCategoryChanged),
        _buildDropdownRow(context: context, label: 'Assigned to:', value: assignedTo, items: teamMemberOptions, onChanged: onOwnerChanged),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 95,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor))),
        ],
      ),
    );
  }

  Widget _buildStaticInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(String label, String value, {VoidCallback? onTap, VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
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
                      color: onTap != null ? Colors.blue.shade700 : null,
                      decoration: onTap != null ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                  if (onClear != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onClear,
                      borderRadius: BorderRadius.circular(20),
                      child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({required BuildContext context, required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged, bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: isStatus ? TextStyle(color: _getStatusColor(item), fontWeight: FontWeight.bold) : null,
                    ),
                  );
                }).toList(),
                onChanged: isResolved ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitledCard({required BuildContext context, required IconData icon, required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      case 'New': return const Color(0xFFD32F2F);
      case 'Waiting Reply': return const Color(0xFFE65100);
      case 'Replied': return const Color(0xFF1976D2);
      case 'In Progress': return const Color(0xFF673AB7);
      case 'On Hold': return const Color(0xFFC2185B);
      case 'Resolved': return const Color(0xFF388E3C);
      default: return Colors.grey.shade700;
    }
  }
}