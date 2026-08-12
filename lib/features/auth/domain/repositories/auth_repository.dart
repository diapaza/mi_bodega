import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';

/// Contrato de autenticación y gestión de usuarios, roles y permisos.
abstract interface class AuthRepository {
  Future<Result<LoginResult>> authenticate(String username, String pin);

  /// Autenticación mediante el PIN de recuperación (recuperación offline).
  Future<Result<LoginResult>> loginWithRecovery(String username, String recoveryPin);

  Stream<List<AppUser>> watchUsers(int storeId);

  Future<Result<List<AppUser>>> listUsers(int storeId);

  /// Crea un usuario hasheando el PIN (transacción + auditoría).
  Future<Result<AppUser>> createUser(UserDraft draft);

  /// Actualiza nombre/apellido y usuario (auditoría).
  Future<Result<AppUser>> updateUserDetails(
    int userId, {
    required String fullName,
    String? username,
  });

  Future<Result<void>> setActive(int userId, bool active);

  Future<Result<void>> changeRole(int userId, int roleId);

  /// Restablece el PIN de un usuario (auditoría).
  Future<Result<void>> resetPin(int userId, String newPin);

  /// Define el PIN de recuperación del propietario (auditoría).
  Future<Result<void>> setRecoveryPin(int userId, String recoveryPin);

  Future<Result<List<Role>>> listRoles();

  Stream<List<Role>> watchRoles();

  /// Crea un rol personalizado y asigna sus permisos.
  Future<Result<Role>> createRole(RoleDraft draft);

  /// Actualiza nombre/descripción y permisos de un rol (solo custom).
  Future<Result<Role>> updateRole(Role role, {List<int> permissionIds});

  Future<Result<void>> setRoleActive(int roleId, bool active);

  /// Elimina un rol (protegido: no roles de sistema ni asignados).
  Future<Result<void>> deleteRole(int roleId);

  Future<Result<List<Permission>>> permissionsForUser(int userId);

  Future<Result<List<Permission>>> permissionsForRole(int roleId);

  /// Permisos del catálogo (seed).
  Future<Result<List<Permission>>> allPermissions();
}
