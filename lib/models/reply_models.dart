// lib/models/reply_models.dart
import 'package:anri/models/ticket_model.dart'; // Import model Attachment

class Reply {
  final int id;
  final String name;
  final String message;
  final DateTime date;
  final List<Attachment> attachments; // <-- TAMBAHKAN BARIS INI

  Reply({
    required this.id,
    required this.name,
    required this.message,
    required this.date,
    this.attachments = const [], // <-- TAMBAHKAN BARIS INI
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    // Proses attachment jika ada
    var attachmentsList = <Attachment>[];
    if (json['attachments'] != null && json['attachments'] is List) {
      attachmentsList = (json['attachments'] as List)
          .map((attJson) => Attachment.fromJson(attJson))
          .toList();
    }

    return Reply(
      id: json['id'] as int,
      name: json['name'] ?? 'Unknown',
      message: json['message'] ?? '',
      date: DateTime.parse(json['dt']),
      attachments: attachmentsList, // <-- TAMBAHKAN BARIS INI
    );
  }
}