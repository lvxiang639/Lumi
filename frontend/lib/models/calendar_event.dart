class CalendarEvent {
  final String id;
  final String title;
  final DateTime time;
  final String repeatRule;
  final bool notified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.time,
    this.repeatRule = 'none',
    this.notified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    time: DateTime.parse(json['time'] as String),
    repeatRule: json['repeat_rule'] as String? ?? 'none',
    notified: json['notified'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'time': time.toIso8601String(),
    'repeat_rule': repeatRule,
  };
}
