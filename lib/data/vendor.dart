class Vendor {
  Vendor({
    required this.id,
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
  final String name;
  final String phone;
  final String email;
  final String address;
  final String company;
  final String notes;
  final int updatedAt;
  final bool dirty;

  Vendor copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? company,
    String? notes,
    int? updatedAt,
    bool? dirty,
  }) {
    return Vendor(
      id: id ?? this.id,
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

  static Vendor fromMap(Map<String, Object?> map) {
    return Vendor(
      id: map['id'] as String,
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

  static Vendor fromJson(String id, Map<dynamic, dynamic> json) {
    return Vendor(
      id: id,
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
