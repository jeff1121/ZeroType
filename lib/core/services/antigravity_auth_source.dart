import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

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
  Future<AntigravityAuthData?>? _refreshing;

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
        return (accessToken: fresh, projectId: projectId);
      }

      final refresh = parsed['refresh_token'] as String?;
      if (refresh != null && refresh.isNotEmpty) {
        final result = await (_refreshing ??= _refreshAndWrite(
          file,
          parsed,
          refresh,
          clientId,
          clientSecret,
          projectId,
        ).whenComplete(() => _refreshing = null));
        if (result != null) return result;
      }
    }
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
      print('[AntigravityAuth] 讀取本機登入失敗：$e');
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
  ) async {
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
        print('[AntigravityAuth] 更新授權失敗：回應沒有 access_token');
        return null;
      }
      final expiresIn = data?['expires_in'];
      final now = DateTime.now();
      final expiryMs = now
          .add(Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600))
          .millisecondsSinceEpoch;

      current['access_token'] = access;
      if (current.containsKey('expiry_date')) {
        current['expiry_date'] = expiryMs;
      }
      if (current.containsKey('expired')) {
        current['expired'] = now
            .add(Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600))
            .toIso8601String();
      }
      final rotatedRefresh = data?['refresh_token'];
      if (rotatedRefresh is String && rotatedRefresh.isNotEmpty) {
        current['refresh_token'] = rotatedRefresh;
      }
      await file.writeAsString(jsonEncode(current));
      return (accessToken: access, projectId: projectId);
    } catch (e) {
      print('[AntigravityAuth] 更新授權失敗：$e');
      return null;
    }
  }
}
