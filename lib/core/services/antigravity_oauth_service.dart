import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_type/core/services/antigravity_auth_source.dart';

/// 透過 Google OAuth 取得 Antigravity 憑證並落地為本機憑證檔。
///
/// 流程參考開源專案 CLIProxyAPI 的 Antigravity OAuth 實作：
/// 1. 以 Antigravity 專用 OAuth client 與 scope 發起授權（含 cclog、
///    experimentsandconfigs）。
/// 2. 本機 callback server 收授權碼，換 access / refresh token。
/// 3. 取得帳號 email 與 Code Assist project id（loadCodeAssist，
///    ideType=ANTIGRAVITY；查不到時以 onboardUser 輪詢補齊）。
/// 4. 落地為 `~/.cli-proxy-api/antigravity-<email>.json`，供
///    [AntigravityAuthSource] 後續讀取、續期與轉寫使用。
class AntigravityOauthService {
  AntigravityOauthService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v2/userinfo?alt=json';
  static const _apiEndpoint = 'https://cloudcode-pa.googleapis.com';
  static const _dailyApiEndpoint = 'https://daily-cloudcode-pa.googleapis.com';
  static const _apiVersion = 'v1internal';

  /// Antigravity OAuth client 已註冊的固定 callback port。
  static const _preferredCallbackPort = 51121;

  static const _ideVersion = '2.2.1';
  static const _userAgent = 'antigravity/hub/$_ideVersion darwin/arm64';
  static const _nodeApiClientUa = 'google-api-nodejs-client/10.3.0';
  static const _googApiClientUa = 'gl-node/22.21.1';

  static const _scopes = [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/cclog',
    'https://www.googleapis.com/auth/experimentsandconfigs',
  ];

  String get _clientId => AntigravityAuthSource.antigravityClientId;
  String get _clientSecret => AntigravityAuthSource.antigravityClientSecret;

  /// 發起 OAuth 登入，成功後回傳落地憑證檔的完整路徑。
  Future<String> login() async {
    final server = await _bindCallbackServer();
    final port = server.port;
    final redirectUri = 'http://localhost:$port/oauth-callback';
    final state = _randomState(16);

    final authUri = Uri.parse(_authEndpoint).replace(
      queryParameters: {
        'access_type': 'offline',
        'client_id': _clientId,
        'prompt': 'consent',
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'state': state,
      },
    );

    final launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await server.close(force: true);
      throw Exception('無法開啟瀏覽器進行 Antigravity 登入');
    }

    try {
      final request = await server.first.timeout(const Duration(minutes: 5));
      final params = request.uri.queryParameters;
      final ok = (params['code'] ?? '').isNotEmpty && params['error'] == null;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          ok
              ? '<html><body>已完成 Antigravity 登入，可以回到 ZeroType。</body></html>'
              : '<html><body>登入失敗，請回到 ZeroType 查看訊息。</body></html>',
        );
      await request.response.close();

      if (params['error'] != null) {
        throw Exception('Antigravity 授權失敗：${params['error']}');
      }
      if (params['state'] != state) {
        throw Exception('OAuth state 不符');
      }
      final code = params['code'];
      if (code == null || code.isEmpty) {
        throw Exception('沒有取得授權碼');
      }

      final token = await _exchangeCode(code: code, redirectUri: redirectUri);
      final email = await _fetchEmail(token.accessToken);
      final projectId = await _fetchProjectId(token.accessToken);
      if (projectId.isEmpty) {
        throw Exception('Antigravity 專案探索失敗（project id 為空）');
      }

      return await _writeCredentialFile(
        email: email,
        projectId: projectId,
        token: token,
      );
    } finally {
      await server.close(force: true);
    }
  }

  Future<HttpServer> _bindCallbackServer() async {
    try {
      return await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _preferredCallbackPort,
      );
    } catch (_) {
      // Google 對 loopback redirect 不校驗 port，改用隨機可用埠。
      return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
  }

  Future<_AntigravityTokenResponse> _exchangeCode({
    required String code,
    required String redirectUri,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _tokenEndpoint,
      data: {
        'code': code,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = response.data;
    final accessToken = (data?['access_token'] as String?)?.trim();
    final refreshToken = (data?['refresh_token'] as String?)?.trim();
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw Exception('Google 未回傳完整 Antigravity 憑證');
    }
    final expiresIn = (data?['expires_in'] as num?)?.toInt() ?? 3600;
    return _AntigravityTokenResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }

  Future<String> _fetchEmail(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _userInfoEndpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': _userAgent,
        },
      ),
    );
    final email = (response.data?['email'] as String?)?.trim();
    if (email == null || email.isEmpty) {
      throw Exception('Antigravity 帳號資訊缺少 email');
    }
    return email;
  }

  /// 透過 loadCodeAssist 取得 project id，查不到時退回 onboardUser 輪詢。
  Future<String> _fetchProjectId(String accessToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_apiEndpoint/$_apiVersion:loadCodeAssist',
      data: {
        'metadata': {'ideType': 'ANTIGRAVITY'},
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': '*/*',
          'Content-Type': 'application/json',
          'User-Agent': _userAgent,
        },
      ),
    );

    final direct = _extractProjectId(response.data);
    if (direct.isNotEmpty) return direct;

    return _onboardUser(accessToken, _defaultTierId(response.data));
  }

  Future<String> _onboardUser(String accessToken, String tierId) async {
    final body = {
      'tier_id': tierId,
      'metadata': {
        'ide_type': 'ANTIGRAVITY',
        'ide_version': _ideVersion,
        'ide_name': 'antigravity',
      },
    };

    const maxAttempts = 5;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_dailyApiEndpoint/$_apiVersion:onboardUser',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': '*/*',
            'Content-Type': 'application/json',
            'User-Agent': '$_userAgent $_nodeApiClientUa',
            'X-Goog-Api-Client': _googApiClientUa,
          },
        ),
      );

      final data = response.data;
      if (data?['done'] == true) {
        final projectId = _extractProjectId(
          data?['response'] as Map<String, dynamic>?,
        );
        if (projectId.isNotEmpty) return projectId;
        return '';
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return '';
  }

  Future<String> _writeCredentialFile({
    required String email,
    required String projectId,
    required _AntigravityTokenResponse token,
  }) async {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) {
      throw Exception('找不到使用者家目錄');
    }

    final now = DateTime.now();
    final expiry = now.add(Duration(seconds: token.expiresIn));
    final payload = <String, dynamic>{
      'type': 'antigravity',
      'access_token': token.accessToken,
      'refresh_token': token.refreshToken,
      'expires_in': token.expiresIn,
      'timestamp': now.millisecondsSinceEpoch,
      'expired': expiry.toUtc().toIso8601String(),
      'expiry_date': expiry.millisecondsSinceEpoch,
      'email': email,
      'project_id': projectId,
    };

    final dir = Directory('$home${Platform.pathSeparator}.cli-proxy-api');
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}${_credentialFileName(email)}',
    );
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }

  String _credentialFileName(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'antigravity.json';
    return 'antigravity-$trimmed.json';
  }

  String _defaultTierId(Map<String, dynamic>? loadResp) {
    final tiers = loadResp?['allowedTiers'];
    if (tiers is List) {
      for (final raw in tiers) {
        if (raw is Map &&
            raw['isDefault'] == true &&
            raw['id'] is String &&
            (raw['id'] as String).trim().isNotEmpty) {
          return (raw['id'] as String).trim();
        }
      }
    }
    final currentTier = loadResp?['currentTier'];
    if (currentTier is Map &&
        currentTier['id'] is String &&
        (currentTier['id'] as String).trim().isNotEmpty) {
      return (currentTier['id'] as String).trim();
    }
    return 'free-tier';
  }

  String _extractProjectId(Map<String, dynamic>? data) {
    if (data == null) return '';
    for (final key in ['cloudaicompanionProject', 'projectId', 'project']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is Map && value['id'] is String) {
        final id = (value['id'] as String).trim();
        if (id.isNotEmpty) return id;
      }
    }
    return '';
  }

  String _randomState(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

class _AntigravityTokenResponse {
  const _AntigravityTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}
