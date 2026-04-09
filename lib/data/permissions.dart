const modules = [
  'customers',
  'suppliers',
  'sales',
  'payments',
  'purchases',
  'supplier_payments',
  'units',
  'reports',
  'settings',
  'users',
  'sync',
  'products',
  'vendors',
  'inventory',
  'approvals',
];

class PermissionSet {
  PermissionSet({
    required this.view,
    required this.create,
    required this.edit,
    required this.remove,
  });

  final bool view;
  final bool create;
  final bool edit;
  final bool remove;

  PermissionSet copyWith({bool? view, bool? create, bool? edit, bool? remove}) {
    return PermissionSet(
      view: view ?? this.view,
      create: create ?? this.create,
      edit: edit ?? this.edit,
      remove: remove ?? this.remove,
    );
  }

  Map<String, Object?> toJson() {
    return {'view': view, 'create': create, 'edit': edit, 'remove': remove};
  }

  static PermissionSet fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) {
      return PermissionSet(
        view: false,
        create: false,
        edit: false,
        remove: false,
      );
    }
    return PermissionSet(
      view: (json['view'] as bool?) ?? false,
      create: (json['create'] as bool?) ?? false,
      edit: (json['edit'] as bool?) ?? false,
      remove: (json['remove'] as bool?) ?? false,
    );
  }
}

Map<String, PermissionSet> defaultPermissionsForRole(String role) {
  switch (role) {
    case 'super_admin':
      return {
        for (final module in modules)
          module: PermissionSet(
            view: true,
            create: true,
            edit: true,
            remove: true,
          ),
      };
    case 'admin':
      return {
        for (final module in modules)
          module: PermissionSet(
            view: true,
            create: true,
            edit: true,
            remove: true,
          ),
      };
    case 'viewer':
      return {
        'customers': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'suppliers': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'sales': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'payments': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'purchases': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'supplier_payments': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'units': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'reports': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'settings': PermissionSet(
          view: false,
          create: false,
          edit: false,
          remove: false,
        ),
        'users': PermissionSet(
          view: false,
          create: false,
          edit: false,
          remove: false,
        ),
        'sync': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'products': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'vendors': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'inventory': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'approvals': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
      };
    case 'staff':
    default:
      return {
        'customers': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'suppliers': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'sales': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'payments': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'purchases': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'supplier_payments': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'units': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'reports': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'settings': PermissionSet(
          view: false,
          create: false,
          edit: false,
          remove: false,
        ),
        'users': PermissionSet(
          view: false,
          create: false,
          edit: false,
          remove: false,
        ),
        'sync': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
        'products': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'vendors': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'inventory': PermissionSet(
          view: true,
          create: true,
          edit: false,
          remove: false,
        ),
        'approvals': PermissionSet(
          view: true,
          create: false,
          edit: false,
          remove: false,
        ),
      };
  }
}

Map<String, PermissionSet> normalizePermissions(
  String role,
  Map<String, PermissionSet> current,
) {
  final defaults = defaultPermissionsForRole(role);
  final merged = <String, PermissionSet>{};
  for (final entry in defaults.entries) {
    if (entry.key == 'sync') {
      merged[entry.key] = entry.value;
      continue;
    }
    merged[entry.key] = current[entry.key] ?? entry.value;
  }
  for (final entry in current.entries) {
    merged.putIfAbsent(entry.key, () => entry.value);
  }
  return merged;
}
