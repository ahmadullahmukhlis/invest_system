class Item {
  Item({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.dirty,
  });

  final String id;
  final String title;
  final int updatedAt;
  final bool dirty;

  Item copyWith({
    String? id,
    String? title,
    int? updatedAt,
    bool? dirty,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  static Item fromMap(Map<String, Object?> map) {
    return Item(
      id: map['id'] as String,
      title: map['title'] as String,
      updatedAt: map['updated_at'] as int,
      dirty: (map['dirty'] as int) == 1,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'updatedAt': updatedAt,
    };
  }

  static Item fromJson(String id, Map<dynamic, dynamic> json) {
    final updatedAtRaw = json['updatedAt'];
    return Item(
      id: id,
      title: (json['title'] as String?) ?? '',
      updatedAt: updatedAtRaw is int ? updatedAtRaw : 0,
      dirty: false,
    );
  }
}
