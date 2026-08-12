/// Entidades de autenticación y roles/permisos.
library;

// ignore_for_file: prefer_initializing_formals


class Role {
  final int? id;
  final String name;
  final String? description;
  final bool isSystem;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Role({
    this.id,
    required this.name,
    this.description,
    this.isSystem = false,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

class Permission {
  final int? id;
  final String code;
  final String name;
  final String module;
  final String? description;

  const Permission({
    this.id,
    required this.code,
    required this.name,
    required this.module,
    this.description,
  });
}

class AppUser {
  final int? id;
  final int storeId;
  final String fullName;
  final String username;
  final int roleId;
  final bool active;
  final bool isOwner;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Hash PBKDF2 (nunca se expone fuera de la capa de datos).
  final String? _pinHash;

  /// Hash PBKDF2 del PIN de recuperación (solo datos).
  final String? _recoveryPinHash;

  const AppUser({
    this.id,
    required this.storeId,
    required this.fullName,
    required this.username,
    required this.roleId,
    this.active = true,
    this.isOwner = false,
    required this.createdAt,
    required this.updatedAt,
    String? pinHash,
    String? recoveryPinHash,
  })  : _pinHash = pinHash,
        _recoveryPinHash = recoveryPinHash;

  /// Solo la capa de datos puede leer el hash.
  String? get pinHash => _pinHash;

  /// Solo la capa de datos puede leer el hash de recuperación.
  String? get recoveryPinHash => _recoveryPinHash;
}

/// Datos para crear un usuario.
class UserDraft {
  final int storeId;
  final String fullName;
  final String username;
  final String pin;
  final int roleId;
  final bool isOwner;

  const UserDraft({
    required this.storeId,
    required this.fullName,
    required this.username,
    required this.pin,
    required this.roleId,
    this.isOwner = false,
  });
}

/// Resultado del intento de login.
class LoginResult {
  final AppUser user;
  final List<String> permissions;

  const LoginResult({required this.user, required this.permissions});
}

/// Datos para crear o actualizar un rol personalizado.
class RoleDraft {
  final String name;
  final String? description;
  final List<int> permissionIds;

  const RoleDraft({
    required this.name,
    this.description,
    this.permissionIds = const [],
  });
}
