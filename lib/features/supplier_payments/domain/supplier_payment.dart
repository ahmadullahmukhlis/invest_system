class SupplierPayment {
  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.amount,
    this.purchaseId,
    this.note,
  });

  final String id;
  final String supplierId;
  final String? purchaseId;
  final DateTime date;
  final double amount;
  final String? note;

  SupplierPayment copyWith({
    String? id,
    String? supplierId,
    String? purchaseId,
    DateTime? date,
    double? amount,
    String? note,
  }) {
    return SupplierPayment(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      purchaseId: purchaseId ?? this.purchaseId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }
}
