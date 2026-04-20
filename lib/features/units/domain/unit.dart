class Unit {
  const Unit({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  Unit copyWith({
    String? id,
    String? name,
    bool? isActive,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
