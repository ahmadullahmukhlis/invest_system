import '../../data/permissions.dart';
import '../../data/user_repository.dart';

bool canView(UserRepository repo, String module) {
  return _has(repo, module, (p) => p.view);
}

bool canCreate(UserRepository repo, String module) {
  return _has(repo, module, (p) => p.create);
}

bool canEdit(UserRepository repo, String module) {
  return _has(repo, module, (p) => p.edit);
}

bool canRemove(UserRepository repo, String module) {
  return _has(repo, module, (p) => p.remove);
}

bool _has(UserRepository repo, String module, bool Function(PermissionSet) test) {
  final role = repo.currentRole;
  if (role == 'admin' || role == 'super_admin') {
    return true;
  }
  final perms = repo.current?.permissions[module];
  if (perms == null) return false;
  return test(perms);
}
