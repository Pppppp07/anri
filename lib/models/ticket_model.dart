// lib/models/ticket_model.dart

// --- BARU: Model untuk data lampiran ---
class Attachment {
  final int id;
  final String realName;
  final String url;
  final int size; // dalam bytes

  Attachment({
    required this.id,
    required this.realName,
    required this.url,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as int,
      realName: json['real_name'] ?? 'unknown_file',
      url: json['url'] ?? '',
      size: json['size'] as int? ?? 0,
    );
  }
}
// --- AKHIR MODEL BARU ---


class Ticket {
  final int id;
  final String trackid;
  final String requesterName;
  final String subject;
  final String message;
  final DateTime creationDate;
  final DateTime lastChange;
  final String statusText;
  final String priorityText;
  final String categoryName;
  final String ownerName;
  final String lastReplierText;
  final int replies;
  final String timeWorked;
  final DateTime? dueDate;
  final String custom1;
  final String custom2;
  // --- BARU: Tambahkan list lampiran di sini ---
  final List<Attachment> attachments;

  Ticket({
    required this.id,
    required this.trackid,
    required this.requesterName,
    required this.subject,
    required this.message,
    required this.creationDate,
    required this.lastChange,
    required this.statusText,
    required this.priorityText,
    required this.categoryName,
    required this.ownerName,
    required this.lastReplierText,
    required this.replies,
    required this.timeWorked,
    this.dueDate,
    required this.custom1,
    required this.custom2,
    this.attachments = const [], // Default ke list kosong
  });

  factory Ticket.fromJson(Map<String, dynamic> json, {List<Attachment> attachments = const []}) {
    return Ticket(
      id: json['id'] as int,
      trackid: json['trackid'] ?? 'N/A',
      requesterName: json['requester_name'] ?? 'Unknown User',
      subject: json['subject'] ?? 'No Subject',
      message: json['message'] ?? '',
      creationDate: DateTime.parse(json['creation_date']),
      lastChange: DateTime.parse(json['lastchange']),
      statusText: json['status_text'] ?? 'Unknown',
      priorityText: json['priority_text'] ?? 'Unknown',
      categoryName: json['category_name'] ?? 'Uncategorized',
      ownerName: json['owner_name'] ?? 'Unassigned',
      lastReplierText: json['last_replier_text'] ?? '-',
      replies: json['replies'] as int? ?? 0,
      timeWorked: json['time_worked'] ?? '00:00:00',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      custom1: json['custom1'] ?? '-',
      custom2: json['custom2'] ?? '-',
      // --- BARU: Isi list lampiran dari data JSON ---
      attachments: attachments,
    );
  }
}

// --- DIHAPUS: Enum ListState yang redundan telah dihapus dari file ini ---