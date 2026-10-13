import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 包含 Antigravity 憑證與關聯的 Project ID。
typedef AntigravityAuthData = ({String accessToken, String projectId});

/// 只引用本機 Antigravity / Gemini 登入。
/// 支援 ~/.cli-proxy-api/ 中的 Antigravity OAuth 憑證，以及 ~/.gemini/oauth_creds.json。
/// access 過期時以對應的 OAuth client 換新並寫回。
class AntigravityAuthSource {
  AntigravityAuthSource({required Dio dio, File? credentialFile})
    : _dio = dio,
      _credentialFileOverride = credentialFile;

  final Dio _dio;
  final File? _credentialFileOverride;
  final Map<String, Future<AntigravityAuthData?>> _refreshing = {};
  final Map<String, String> _catalogIdentities = <String, String>{};
  final Map<String, String> _authCatalogIdentities = <String, String>{};
  String? _catalogIdentity;

  /// 最近一次有效授權的目錄隔離識別，不包含原始 token、帳號或檔案路徑。
  /// 短期 token 更新與本來源執行的 refresh token 輪替不改變此識別。
  String? get catalogIdentity => _catalogIdentity;

  /// 綁定某次回傳授權的識別，避免並行讀取另一帳號改變最近一次識別。
  /// 索引只保存 token 與 project 的雜湊，不另行保存原始 token。
  String? catalogIdentityFor(AntigravityAuthData auth) =>
      _authCatalogIdentities[_authFingerprint(auth)];

  String _authFingerprint(AntigravityAuthData auth) => sha256
      .convert(utf8.encode(jsonEncode([auth.accessToken, auth.projectId])))
      .toString();

  AntigravityAuthData _rememberAuth(AntigravityAuthData auth, String identity) {
    _authCatalogIdentities[_authFingerprint(auth)] = identity;
    _catalogIdentity = identity;
    return auth;
  }

  String _snapshotFingerprint(Map<String, dynamic> credential) =>
      sha256.convert(utf8.encode(jsonEncode(credential))).toString();

  String _credentialFingerprint(
    File file,
    Map<String, dynamic> credential,
    String projectId,
  ) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            file.absolute.path,
            credential['email'],
            projectId,
            credential['refresh_token'] ??
                (credential['email'] == null
                    ? credential['access_token']
                    : null),
          ]),
        ),
      )
      .toString();

  String _identityFor(
    File file,
    Map<String, dynamic> credential,
    String projectId,
  ) {
    final fingerprint = _credentialFingerprint(file, credential, projectId);
    return _catalogIdentities.putIfAbsent(fingerprint, () => fingerprint);
  }

  /// Antigravity 原生 OAuth Client
  static String get antigravityClientId => _xor([
    107,
    106,
    109,
    107,
    106,
    106,
    108,
    106,
    108,
    106,
    111,
    99,
    107,
    119,
    46,
    55,
    50,
    41,
    41,
    51,
    52,
    104,
    50,
    104,
    107,
    54,
    57,
    40,
    63,
    104,
    105,
    111,
    44,
    46,
    53,
    54,
    53,
    48,
    50,
    110,
    61,
    110,
    106,
    105,
    63,
    42,
    116,
    59,
    42,
    42,
    41,
    116,
    61,
    53,
    53,
    61,
    54,
    63,
    47,
    41,
    63,
    40,
    57,
    53,
    52,
    46,
    63,
    52,
    46,
    116,
    57,
    53,
    55,
  ]);

  static String get antigravityClientSecret => _xor([
    29,
    21,
    25,
    9,
    10,
    2,
    119,
    17,
    111,
    98,
    28,
    13,
    8,
    110,
    98,
    108,
    22,
    62,
    22,
    16,
    107,
    55,
    22,
    24,
    98,
    41,
    2,
    25,
    110,
    32,
    108,
    43,
    30,
    27,
    60,
  ]);

  /// Gemini CLI 公開 OAuth Client
  static String get geminiCliClientId => _xor([
    108,
    98,
    107,
    104,
    111,
    111,
    98,
    106,
    99,
    105,
    99,
    111,
    119,
    53,
    53,
    98,
    60,
    46,
    104,
    53,
    42,
    40,
    62,
    40,
    52,
    42,
    99,
    63,
    105,
    59,
    43,
    60,
    108,
    59,
    44,
    105,
    50,
    55,
    62,
    51,
    56,
    107,
    105,
    111,
    48,
    116,
    59,
    42,
    42,
    41,
    116,
    61,
    53,
    53,
    61,
    54,
    63,
    47,
    41,
    63,
    40,
    57,
    53,
    52,
    46,
    63,
    52,
    46,
    116,
    57,
    53,
    55,
  ]);

  static String get geminiCliClientSecret => _xor([
    29,
    21,
    25,
    9,
    10,
    2,
    119,
    110,
    47,
    18,
    61,
    23,
    10,
    55,
    119,
    107,
    53,
    109,
    9,
    49,
    119,
    61,
    63,
    12,
    108,
    25,
    47,
    111,
    57,
    54,
    2,
    28,
    41,
    34,
    54,
  ]);

  static String _xor(List<int> bytes) =>
      String.fromCharCodes(bytes.map((b) => b ^ 0x5A));

  static const tokenUri = 'https://oauth2.googleapis.com/token';

  List<File> get _candidateFiles {
    if (_credentialFileOverride != null) return [_credentialFileOverride];
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final files = <File>[];

    // 1. 優先檢查 ~/.cli-proxy-api/ 中的 antigravity-*.json
    final proxyDir = Directory('$home${Platform.pathSeparator}.cli-proxy-api');
    if (proxyDir.existsSync()) {
      try {
        final agFiles =
            proxyDir
                .listSync()
                .whereType<File>()
                .where(
                  (f) => f.uri.pathSegments.last.startsWith('antigravity-'),
                )
                .toList()
              ..sort(
                (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
              );
        files.addAll(agFiles);
      } catch (_) {}
    }

    // 2. 備選 ~/.gemini/oauth_creds.json
    files.add(
      File(
        '$home${Platform.pathSeparator}.gemini${Platform.pathSeparator}oauth_creds.json',
      ),
    );

    return files;
  }

  /// 是否有可用的 Antigravity 憑證檔案
  Future<bool> get isAvailable async => (await getAuthData()) != null;

  /// 取得有效的 Token 與 Project ID
  Future<AntigravityAuthData?> getAuthData() async {
    for (final file in _candidateFiles) {
      if (!file.existsSync()) continue;
      final parsed = await _readFile(file);
      if (parsed == null) continue;

      final isAntigravityClient = file.uri.pathSegments.last.startsWith(
        'antigravity-',
      );
      final clientId = isAntigravityClient
          ? antigravityClientId
          : geminiCliClientId;
      final clientSecret = isAntigravityClient
          ? antigravityClientSecret
          : geminiCliClientSecret;
      final projectId =
          (parsed['project_id'] as String?) ??
          (parsed['cloudaicompanionProject'] as String?) ??
          '';

      final fresh = _freshAccessToken(parsed);
      if (fresh != null) {
        return _rememberAuth((
          accessToken: fresh,
          projectId: projectId,
        ), _identityFor(file, parsed, projectId));
      }

      final refresh = parsed['refresh_token'] as String?;
      if (refresh != null && refresh.isNotEmpty) {
        final identity = _identityFor(file, parsed, projectId);
        final fingerprint = _credentialFingerprint(file, parsed, projectId);
        try {
          final result = await _refreshing.putIfAbsent(
            fingerprint,
            () =>
                _refreshAndWrite(
                  file,
                  parsed,
                  refresh,
                  clientId,
                  clientSecret,
                  projectId,
                  identity,
                ).whenComplete(() {
                  _refreshing.remove(fingerprint);
                }),
          );
          if (result != null) return _rememberAuth(result, identity);
        } on _CredentialSnapshotChanged {
          // 晚到的舊授權不改寫目前帳號，也不自動改用另一份憑證。
          return null;
        }
      }
    }
    _catalogIdentity = null;
    return null;
  }

  Future<String?> readAccessToken() async {
    final data = await getAuthData();
    return data?.accessToken;
  }

  Future<Map<String, dynamic>?> _readFile(File file) async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
      return null;
    } catch (e) {
      debugPrint('[AntigravityAuth] 讀取本機登入失敗：${e.runtimeType}');
      return null;
    }
  }

  String? _freshAccessToken(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) return null;
    final expiryRaw = json['expiry_date'] ?? json['expired'];
    if (expiryRaw is num) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryRaw.toInt());
      if (!expiry.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
        return null;
      }
    } else if (expiryRaw is String) {
      try {
        final expiry = DateTime.parse(expiryRaw);
        if (!expiry.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
          return null;
        }
      } catch (_) {}
    }
    return accessToken;
  }

  Future<AntigravityAuthData?> _refreshAndWrite(
    File file,
    Map<String, dynamic> current,
    String refreshToken,
    String clientId,
    String clientSecret,
    String projectId,
    String identity,
  ) async {
    final String expectedSnapshot = _snapshotFingerprint(current);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        tokenUri,
        data: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = response.data;
      final access = data?['access_token'] as String?;
      if (access == null || access.isEmpty) {
        debugPrint('[AntigravityAuth] 更新授權失敗：回應沒有 access_token');
        return null;
      }
      final expiresIn = data?['expires_in'];
      final now = DateTime.now();
      final expiryMs = now
          .add(Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600))
          .millisecondsSinceEpoch;

      final Map<String, dynamic> updated = {...current, 'access_token': access};
      if (updated.containsKey('expiry_date')) {
        updated['expiry_date'] = expiryMs;
      }
      if (updated.containsKey('expired')) {
        updated['expired'] = now
            .add(Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600))
            .toIso8601String();
      }
      final rotatedRefresh = data?['refresh_token'];
      if (rotatedRefresh is String && rotatedRefresh.isNotEmpty) {
        updated['refresh_token'] = rotatedRefresh;
      }
      final Map<String, dynamic>? latest = file.existsSync()
          ? await _readFile(file)
          : null;
      if (latest == null || _snapshotFingerprint(latest) != expectedSnapshot) {
        throw const _CredentialSnapshotChanged();
      }
      await file.writeAsString(jsonEncode(updated));
      // refresh token 輪替後，下次讀檔仍屬於原本的授權情境。
      _catalogIdentities[_credentialFingerprint(file, updated, projectId)] =
          identity;
      return (accessToken: access, projectId: projectId);
    } on _CredentialSnapshotChanged {
      rethrow;
    } catch (e) {
      debugPrint('[AntigravityAuth] 更新授權失敗：${e.runtimeType}');
      return null;
    }
  }
}

class _CredentialSnapshotChanged implements Exception {
  const _CredentialSnapshotChanged();
}
