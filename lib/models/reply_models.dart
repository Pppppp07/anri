class Reply {
  final int id;
  final String name;
  final String message;
  final DateTime date;

  Reply({
    required this.id,
    required this.name,
    required this.message,
    required this.date,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['id'] as int,
      name: json['name'] ?? 'Unknown',
      message: json['message'] ?? '',
      date: DateTime.parse(json['dt']),
    );
  }
}
