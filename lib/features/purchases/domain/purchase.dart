class Purchase {
  const Purchase({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.quantityValue,
    required this.unitId,
    required this.pricePerUnit,
    required this.totalPrice,
    this.note,
  });

  final String id;
  final String supplierId;
  final DateTime date;
  final double quantityValue;
  final String unitId;
  final double pricePerUnit;
  final double totalPrice;
  final String? note;

  Purchase copyWith({
    String? id,
    String? supplierId,
    DateTime? date,
    double? quantityValue,
    String? unitId,
    double? pricePerUnit,
    double? totalPrice,
    String? note,
  }) {
    return Purchase(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      date: date ?? this.date,
      quantityValue: quantityValue ?? this.quantityValue,
      unitId: unitId ?? this.unitId,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalPrice: totalPrice ?? this.totalPrice,
      note: note ?? this.note,
    );
  }
}
