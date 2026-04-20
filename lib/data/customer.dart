class Customer {
  Customer({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.company,
    required this.notes,
    required this.updatedAt,
    required this.dirty,
  });

  final String id;
  final String ownerUid;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String company;
  final String notes;
  final int updatedAt;
  final bool dirty;

  Customer copyWith({
    String? id,
    String? ownerUid,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? company,
    String? notes,
    int? updatedAt,
    bool? dirty,
  }) {
    return Customer(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      company: company ?? this.company,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'owner_uid': ownerUid,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'company': company,
      'notes': notes,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  static Customer fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as String,
      ownerUid: (map['owner_uid'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      company: (map['company'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      updatedAt: (map['updated_at'] as int?) ?? 0,
      dirty: (map['dirty'] as int?) == 1,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'company': company,
      'notes': notes,
      'updatedAt': updatedAt,
    };
  }

  static Customer fromJson(
    String id,
    String ownerUid,
    Map<dynamic, dynamic> json,
  ) {
    return Customer(
      id: id,
      ownerUid: ownerUid,
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      company: (json['company'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      updatedAt: (json['updatedAt'] as int?) ?? 0,
      dirty: false,
    );
  }
}
