import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import 'local_db_service.dart';

class BackupService {
  static const _backupFileName = 'recipe_saver_backup.json';

  final LocalDbService _db;
  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );

  BackupService(this._db);

  Future<drive.DriveApi> _getDriveApi() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Sign-in cancelled');
    final auth = await account.authentication;
    final client = _AuthClient({'Authorization': 'Bearer ${auth.accessToken}'});
    return drive.DriveApi(client);
  }

  Future<DateTime?> getLastBackupTime() async {
    try {
      final driveApi = await _getDriveApi();
      final result = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(modifiedTime)',
      );
      return result.files?.firstOrNull?.modifiedTime;
    } catch (_) {
      return null;
    }
  }

  Future<void> backup() async {
    final recipes = await _db.getAllRecipeDetails();
    final jsonBytes = utf8.encode(jsonEncode(recipes.map((r) => r.toJson()).toList()));

    final driveApi = await _getDriveApi();

    final existing = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );

    final media = drive.Media(Stream.value(jsonBytes), jsonBytes.length);

    if (existing.files?.isNotEmpty == true) {
      await driveApi.files.update(
        drive.File(),
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      final file = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];
      await driveApi.files.create(file, uploadMedia: media);
    }
  }

  Future<int> restore() async {
    final driveApi = await _getDriveApi();
    final result = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );

    if (result.files == null || result.files!.isEmpty) {
      throw Exception('No backup found in Google Drive');
    }

    final media = await driveApi.files.get(
      result.files!.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final list = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
    final recipes = list
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
    await _db.importRecipes(recipes);
    return recipes.length;
  }
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}
