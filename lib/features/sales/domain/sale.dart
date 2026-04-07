class Sale {
  const Sale({
    required this.id,
    required this.customerId,
    required this.date,
    required this.quantityValue,
    required this.unitId,
    required this.pricePerUnit,
    required this.totalPrice,
    this.note,
  });

  final String id;
  final String customerId;
  final DateTime date;
  final double quantityValue;
  final String unitId;
  final double pricePerUnit;
  final double totalPrice;
  final String? note;

  Sale copyWith({
    String? id,
    String? customerId,
    DateTime? date,
    double? quantityValue,
    String? unitId,
    double? pricePerUnit,
    double? totalPrice,
    String? note,
  }) {
    return Sale(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      date: date ?? this.date,
      quantityValue: quantityValue ?? this.quantityValue,
      unitId: unitId ?? this.unitId,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalPrice: totalPrice ?? this.totalPrice,
      note: note ?? this.note,
    );
  }
}
