class Product {
  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.unit,
    required this.price,
    required this.cost,
    required this.stock,
    required this.notes,
    required this.updatedAt,
    required this.dirty,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String unit;
  final double price;
  final double cost;
  final double stock;
  final String notes;
  final int updatedAt;
  final bool dirty;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    String? unit,
    double? price,
    double? cost,
    double? stock,
    String? notes,
    int? updatedAt,
    bool? dirty,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'unit': unit,
      'price': price,
      'cost': cost,
      'stock': stock,
      'notes': notes,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  static Product fromMap(Map<String, Object?> map) {
    double asDouble(Object? value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return 0;
    }

    return Product(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      sku: (map['sku'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? '',
      price: asDouble(map['price']),
      cost: asDouble(map['cost']),
      stock: asDouble(map['stock']),
      notes: (map['notes'] as String?) ?? '',
      updatedAt: (map['updated_at'] as int?) ?? 0,
      dirty: (map['dirty'] as int?) == 1,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'sku': sku,
      'category': category,
      'unit': unit,
      'price': price,
      'cost': cost,
      'stock': stock,
      'notes': notes,
      'updatedAt': updatedAt,
    };
  }

  static Product fromJson(String id, Map<dynamic, dynamic> json) {
    double asDouble(Object? value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return 0;
    }

    return Product(
      id: id,
      name: (json['name'] as String?) ?? '',
      sku: (json['sku'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? '',
      price: asDouble(json['price']),
      cost: asDouble(json['cost']),
      stock: asDouble(json['stock']),
      notes: (json['notes'] as String?) ?? '',
      updatedAt: (json['updatedAt'] as int?) ?? 0,
      dirty: false,
    );
  }
}
