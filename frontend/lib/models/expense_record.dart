class ExpenseRecord {
  final String id;
  final double amount;
  final String category;
  final String remark;
  final DateTime recordedAt;
  final DateTime createdAt;

  const ExpenseRecord({
    required this.id,
    required this.amount,
    this.category = '其他',
    this.remark = '',
    required this.recordedAt,
    required this.createdAt,
  });

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    category: json['category'] as String? ?? '其他',
    remark: json['remark'] as String? ?? '',
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'category': category,
    'remark': remark,
    'recorded_at': recordedAt.toIso8601String(),
  };
}
