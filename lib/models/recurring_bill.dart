class RecurringBill {
  final int? id;
  final double amount;
  final String description;
  final String category;
  final String frequency;
  final DateTime nextDueDate;

  RecurringBill({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.frequency,
    required this.nextDueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'frequency': frequency,
      'nextDueDate': nextDueDate.toIso8601String(),
    };
  }
}