import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

enum SessionStatus { initializing, pendingSetup, unauthenticated, authenticated }

/// Estado global de la sesión.
class SessionState {
  final SessionStatus status;
  final AppUser? user;
  final List<String> permissions;
  final Store? store;
  final String? errorMessage;

  const SessionState({
    required this.status,
    this.user,
    this.permissions = const [],
    this.store,
    this.errorMessage,
  });

  const SessionState.initializing() : this(status: SessionStatus.initializing);

  bool can(String permission) => permissions.contains(permission);
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Permisos del usuario de la sesión actual (para guards de lógica).
final sessionPermissionsProvider = Provider<Set<String>>((ref) {
  return ref.watch(sessionControllerProvider).valueOrNull?.permissions.toSet() ??
      const {};
});

class SessionController extends AsyncNotifier<SessionState> {
  Store? _store;

  @override
  Future<SessionState> build() async {
    final storeResult = await ref.read(storeRepositoryProvider).getStore();
    _store = storeResult.orNull;
    if (_store == null) {
      return const SessionState(status: SessionStatus.pendingSetup);
    }
    final restored = await ref.read(authServiceProvider).restoreSession();
    final user = restored.orNull;
    if (user == null) {
      return SessionState(
        status: SessionStatus.unauthenticated,
        store: _store,
      );
    }
    return _authedState(user);
  }

  Future<SessionState> _authedState(AppUser user) async {
    final perms = await ref.read(authRepositoryProvider).permissionsForUser(user.id!);
    return SessionState(
      status: SessionStatus.authenticated,
      user: user,
      store: _store,
      permissions: perms.orNull?.map((p) => p.code).toList() ?? const [],
    );
  }

  Future<void> login(String username, String pin) async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).login(username, pin);
    result.fold(
      (login) {
        state = AsyncData(SessionState(
          status: SessionStatus.authenticated,
          user: login.user,
          store: _store,
          permissions: login.permissions,
        ));
      },
      (failure) {
        state = AsyncData(SessionState(
          status: SessionStatus.unauthenticated,
          store: _store,
          errorMessage: failure.message,
        ));
      },
    );
  }

  Future<void> loginWithRecovery(String username, String recoveryPin) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authServiceProvider).loginWithRecovery(username, recoveryPin);
    result.fold(
      (login) {
        state = AsyncData(SessionState(
          status: SessionStatus.authenticated,
          user: login.user,
          store: _store,
          permissions: login.permissions,
        ));
      },
      (failure) {
        state = AsyncData(SessionState(
          status: SessionStatus.unauthenticated,
          store: _store,
          errorMessage: failure.message,
        ));
      },
    );
  }

  /// Primer arranque: crea la tienda + propietario y establece la sesión.
  Future<void> completeSetup({
    required String storeName,
    String? rucDni,
    String? address,
    String? phone,
    required String ownerFullName,
    required String ownerUsername,
    required String ownerPin,
    required String ownerRecoveryPin,
  }) async {
    state = const AsyncLoading();
    final bootstrap = ref.read(bootstrapServiceProvider);
    final result = await bootstrap.setup(
      storeName: storeName,
      rucDni: rucDni,
      address: address,
      phone: phone,
      ownerFullName: ownerFullName,
      ownerUsername: ownerUsername,
      ownerPin: ownerPin,
      ownerRecoveryPin: ownerRecoveryPin,
    );
    if (result.store != null) {
      _store = result.store;
      await login(ownerUsername, ownerPin);
    } else {
      state = AsyncData(const SessionState(
        status: SessionStatus.pendingSetup,
        errorMessage: 'No se pudo completar la configuración inicial.',
      ));
    }
  }

  Future<void> logout() async {
    final user = state.valueOrNull?.user;
    await ref.read(authServiceProvider).logout(userId: user?.id);
    state = AsyncData(SessionState(
      status: SessionStatus.unauthenticated,
      store: _store,
    ));
  }

  /// Reinicia el estado para el arranque (tests).
  Future<void> refresh() => build();
}
