import 'package:anri/models/reply_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:anri/pages/attachment_viewer_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ReplyHistoryTabView extends StatelessWidget {
  final bool isLoadingDetails;
  final List<Reply> replies;
  final bool isResolved;
  final Widget replyForm;

  const ReplyHistoryTabView({
    super.key,
    required this.isLoadingDetails,
    required this.replies,
    required this.isResolved,
    required this.replyForm,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 1,
            shadowColor: Colors.black.withAlpha(26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                maintainState: true,
                initiallyExpanded: true,
                title: Row(
                  children: [
                    // DIUBAH: Warna ikon dibuat adaptif
                    Icon(Icons.forum_outlined, color: Theme.of(context).textTheme.bodyLarge?.color),
                    const SizedBox(width: 16),
                    // DIUBAH: Warna teks dibuat adaptif
                    Text("Riwayat Balasan (${replies.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                children: [
                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildRepliesList(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!isResolved)
            _buildTitledCard(
              context: context,
              icon: Icons.reply,
              title: "Balas Tiket",
              child: replyForm,
            ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes, int decimals) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

Future<void> _launchAttachmentUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tidak dapat membuka file: $url')),
            );
        }
    }
}


Widget _buildRepliesList(BuildContext context) {
  if (isLoadingDetails) {
    return const Center(child: CircularProgressIndicator());
  }
  if (replies.isEmpty) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text('Belum ada balasan.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
      ),
    );
  }
  return ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: replies.length,
    separatorBuilder: (context, index) => const Divider(height: 24),
    itemBuilder: (context, index) {
      final reply = replies[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(reply.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                DateFormat('d MMM yy, HH:mm').format(reply.date),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Html(data: reply.message),

          // TAMPILKAN LAMPIRAN DI SINI
          if (reply.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Lampiran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            ...reply.attachments.map((att) {
              return Card(
                margin: const EdgeInsets.only(top: 4),
                child: ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(att.realName, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(_formatBytes(att.size, 2)),
                  onTap: () {
                     final name = att.realName.toLowerCase();
                     final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].any((ext) => name.endsWith(ext));
                     final isPdf = name.endsWith('.pdf');
                     if (isImage || isPdf) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AttachmentViewerPage(attachment: att),
                            ),
                        );
                     } else {
                       _launchAttachmentUrl(context, att.url);
                     }
                  },
                ),
              );
            }).toList(),
          ]
        ],
      );
    },
  );
}

   Widget _buildTitledCard({ required BuildContext context, required IconData icon, required String title, required Widget child }) {
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
                // DIUBAH: Warna ikon dibuat adaptif
                Icon(icon, color: Theme.of(context).textTheme.bodyLarge?.color, size: 20),
                const SizedBox(width: 12),
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
}