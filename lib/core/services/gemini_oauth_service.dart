import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_type/features/model_config/domain/repositories/model_config_repository.dart';

class GeminiOauthConfig {
  const GeminiOauthConfig({
    required this.clientId,
    required this.authUri,
    required this.tokenUri,
    required this.revokeUri,
    required this.scopes,
  });

  final String clientId;
  final String authUri;
  final String tokenUri;
  final String revokeUri;
  final List<String> scopes;

  bool get isConfigured => clientId.trim().isNotEmpty;
}

class GeminiOauthService {
  GeminiOauthService({
    required Dio dio,
    required ModelConfigRepository repository,
  }) : _dio = dio,
       _repository = repository;

  final Dio _dio;
  final ModelConfigRepository _repository;

  Future<GeminiOauthConfig> loadConfig() async {
    final raw = await rootBundle.loadString('assets/config/oauth.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return GeminiOauthConfig(
      clientId: json['clientId'] as String? ?? '',
      authUri:
          json['authUri'] as String? ??
          'https://accounts.google.com/o/oauth2/v2/auth',
      tokenUri:
          json['tokenUri'] as String? ?? 'https://oauth2.googleapis.com/token',
      revokeUri:
          json['revokeUri'] as String? ??
          'https://oauth2.googleapis.com/revoke',
      scopes: (json['scopes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Future<bool> get isConnected async =>
      (await _repository.getGeminiOauthTokens()) != null;

  Future<GeminiOauthTokens> login() async {
    final config = await loadConfig();
    if (!config.isConfigured) {
      throw Exception('尚未設定 ZeroType OAuth client');
    }

    final verifier = _randomUrlSafe(32);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/callback';
    final state = _randomUrlSafe(16);

    final authUri = Uri.parse(config.authUri).replace(
      queryParameters: {
        'client_id': config.clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': config.scopes.join(' '),
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
        'state': state,
      },
    );

    final launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await server.close(force: true);
      throw Exception('無法開啟瀏覽器進行 Google 登入');
    }

    try {
      final request = await server.first.timeout(const Duration(minutes: 5));
      final params = request.uri.queryParameters;
      request.response
        ..headers.contentType = ContentType.html
        ..write('<html><body>已完成登入，可以回到 ZeroType。</body></html>');
      await request.response.close();

      if (params['error'] != null) {
        throw Exception('Google 授權失敗：${params['error']}');
      }
      if (params['state'] != state) {
        throw Exception('OAuth state 不符');
      }
      final code = params['code'];
      if (code == null || code.isEmpty) {
        throw Exception('沒有取得授權碼');
      }

      final tokens = await _exchangeCode(
        config: config,
        code: code,
        redirectUri: redirectUri,
        verifier: verifier,
      );
      await _repository.saveGeminiOauthTokens(tokens);
      return tokens;
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> resolveAccessToken() async {
    final stored = await _repository.getGeminiOauthTokens();
    if (stored == null) {
      throw Exception('Gemini OAuth 憑證失效');
    }
    if (stored.isAccessTokenFresh) return stored.accessToken;
    final refreshed = await _refresh(stored);
    await _repository.saveGeminiOauthTokens(refreshed);
    return refreshed.accessToken;
  }

  Future<void> disconnect() async {
    final stored = await _repository.getGeminiOauthTokens();
    final config = await loadConfig();
    if (stored != null && config.isConfigured) {
      try {
        await _dio.post<void>(
          config.revokeUri,
          data: 'token=${stored.refreshToken}',
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
      } catch (e) {
        print('[GeminiOauth] 撤銷授權失敗：$e');
      }
    }
    await _repository.clearGeminiOauthTokens();
  }

  Future<GeminiOauthTokens> _exchangeCode({
    required GeminiOauthConfig config,
    required String code,
    required String redirectUri,
    required String verifier,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      config.tokenUri,
      data: {
        'client_id': config.clientId,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _tokensFromResponse(response.data);
  }

  Future<GeminiOauthTokens> _refresh(GeminiOauthTokens current) async {
    final config = await loadConfig();
    if (!config.isConfigured) {
      throw Exception('尚未設定 ZeroType OAuth client');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        config.tokenUri,
        data: {
          'client_id': config.clientId,
          'grant_type': 'refresh_token',
          'refresh_token': current.refreshToken,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final next = _tokensFromResponse(
        response.data,
        fallbackRefreshToken: current.refreshToken,
      );
      return next;
    } catch (e) {
      throw Exception('Gemini OAuth 憑證失效');
    }
  }

  GeminiOauthTokens _tokensFromResponse(
    Map<String, dynamic>? data, {
    String? fallbackRefreshToken,
  }) {
    final accessToken = data?['access_token'] as String?;
    final refreshToken =
        data?['refresh_token'] as String? ?? fallbackRefreshToken;
    final expiresIn = data?['expires_in'] as num? ?? 3600;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw Exception('Google 未回傳完整 OAuth 憑證');
    }
    return GeminiOauthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiry: DateTime.now().add(Duration(seconds: expiresIn.toInt())),
    );
  }

  String _randomUrlSafe(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
