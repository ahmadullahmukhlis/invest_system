class Payment {
  const Payment({
    required this.id,
    required this.customerId,
    required this.date,
    required this.amount,
    this.saleId,
    this.note,
  });

  final String id;
  final String customerId;
  final String? saleId;
  final DateTime date;
  final double amount;
  final String? note;

  Payment copyWith({
    String? id,
    String? customerId,
    String? saleId,
    DateTime? date,
    double? amount,
    String? note,
  }) {
    return Payment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      saleId: saleId ?? this.saleId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }
}
