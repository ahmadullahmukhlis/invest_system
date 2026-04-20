class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.province,
    required this.district,
    this.address,
  });

  final String id;
  final String name;
  final String phone;
  final String province;
  final String district;
  final String? address;

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? province,
    String? district,
    String? address,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      province: province ?? this.province,
      district: district ?? this.district,
      address: address ?? this.address,
    );
  }
}
