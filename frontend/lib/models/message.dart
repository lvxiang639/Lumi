class Message {
  final String id;
  final String role;
  final String type;
  final String content;
  final String audioUrl;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.role,
    required this.type,
    required this.content,
    this.audioUrl = '',
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    role: json['role'] as String,
    type: json['type'] as String,
    content: json['content'] as String? ?? '',
    audioUrl: json['audio_url'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
