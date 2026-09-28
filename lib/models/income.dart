class Income {
  final int? id;
  final double amount;
  final String description;
  final DateTime date;

  Income({
    this.id,
    required this.amount,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
    };
  }
}