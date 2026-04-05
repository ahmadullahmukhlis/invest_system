class Purchase {
  Purchase({
    required this.id,
    required this.vendorName,
    required this.reference,
    required this.total,
    required this.status,
    required this.notes,
    required this.purchasedAt,
    required this.updatedAt,
    required this.dirty,
  });

  final String id;
  final String vendorName;
  final String reference;
  final double total;
  final String status;
  final String notes;
  final int purchasedAt;
  final int updatedAt;
  final bool dirty;

  Purchase copyWith({
    String? id,
    String? vendorName,
    String? reference,
    double? total,
    String? status,
    String? notes,
    int? purchasedAt,
    int? updatedAt,
    bool? dirty,
  }) {
    return Purchase(
      id: id ?? this.id,
      vendorName: vendorName ?? this.vendorName,
      reference: reference ?? this.reference,
      total: total ?? this.total,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'vendor_name': vendorName,
      'reference': reference,
      'total': total,
      'status': status,
      'notes': notes,
      'purchased_at': purchasedAt,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  static Purchase fromMap(Map<String, Object?> map) {
    double asDouble(Object? value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return 0;
    }

    return Purchase(
      id: map['id'] as String,
      vendorName: (map['vendor_name'] as String?) ?? '',
      reference: (map['reference'] as String?) ?? '',
      total: asDouble(map['total']),
      status: (map['status'] as String?) ?? 'Draft',
      notes: (map['notes'] as String?) ?? '',
      purchasedAt: (map['purchased_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      dirty: (map['dirty'] as int?) == 1,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'vendorName': vendorName,
      'reference': reference,
      'total': total,
      'status': status,
      'notes': notes,
      'purchasedAt': purchasedAt,
      'updatedAt': updatedAt,
    };
  }

  static Purchase fromJson(String id, Map<dynamic, dynamic> json) {
    double asDouble(Object? value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return 0;
    }

    return Purchase(
      id: id,
      vendorName: (json['vendorName'] as String?) ?? '',
      reference: (json['reference'] as String?) ?? '',
      total: asDouble(json['total']),
      status: (json['status'] as String?) ?? 'Draft',
      notes: (json['notes'] as String?) ?? '',
      purchasedAt: (json['purchasedAt'] as int?) ?? 0,
      updatedAt: (json['updatedAt'] as int?) ?? 0,
      dirty: false,
    );
  }
}
