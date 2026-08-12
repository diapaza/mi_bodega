import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as g;
import 'package:http/http.dart' as http;

import 'drive_client.dart';

/// Cliente real de Google Drive mediante `google_sign_in` + `googleapis`.
///
/// Usa la carpeta privada de la app (`appDataFolder`) con scope `drive.file`.
/// Los tokens OAuth los gestiona el plugin y se guardan en el almacén de
/// credenciales del sistema operativo.
class GoogleDriveClient implements DriveClient {
  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';

  bool _initialized = false;
  bool _signedIn = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  @override
  Future<bool> isSignedIn() async => _signedIn;

  @override
  Future<String?> signIn() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const [_driveScope],
    );
    _signedIn = true;
    return account.email;
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _signedIn = false;
  }

  Future<g.DriveApi> _api() async {
    final authz = await GoogleSignIn.instance.authorizationClient
        .authorizeScopes(const [_driveScope]);
    return g.DriveApi(_AuthedClient(authz.accessToken));
  }

  @override
  Future<void> upload({required String name, required List<int> bytes}) async {
    final drive = await _api();
    final file = g.File();
    file.name = name;
    file.parents = ['appDataFolder'];
    await drive.files.create(
      file,
      uploadMedia: g.Media(Stream.value(bytes), bytes.length),
      $fields: 'id',
    );
  }

  @override
  Future<List<DriveBackupFile>> list() async {
    final drive = await _api();
    final result = await drive.files.list(
      q: "'appDataFolder' in parents and trashed = false",
      spaces: 'appDataFolder',
      $fields: 'files(id,name,size,modifiedTime)',
      orderBy: 'createdTime desc',
    );
    return [
      for (final f in result.files ?? <g.File>[])
        DriveBackupFile(
          id: f.id ?? '',
          name: f.name ?? '',
          size: int.tryParse(f.size ?? '0') ?? 0,
          modified: f.modifiedTime?.toLocal(),
        ),
    ];
  }

  @override
  Future<List<int>?> download(String id) async {
    final drive = await _api();
    final result = await drive.files.get(
      id,
      downloadOptions: g.DownloadOptions.fullMedia,
    );
    if (result is! g.Media) return null;
    final builder = BytesBuilder();
    await for (final chunk in result.stream) {
      builder.add(chunk);
    }
    return builder.takeBytes().toList();
  }

  @override
  Future<void> delete(String id) async {
    final drive = await _api();
    await drive.files.delete(id);
  }
}

/// Cliente HTTP que inyecta el token OAuth en cada petición.
class _AuthedClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _AuthedClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
