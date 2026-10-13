import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/services/antigravity_auth_source.dart';

void main() {
  late Directory tempDir;
  late File creds;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zerotype-ag-');
    creds = File('${tempDir.path}/oauth_creds.json');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('未過期的 access_token 直接回傳，不打網路', () async {
    final expiry = DateTime.now()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'fresh-token',
        'refresh_token': 'refresh-token',
        'expiry_date': expiry,
      }),
    );
    final source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = _FailAdapter(),
      credentialFile: creds,
    );

    expect(await source.isAvailable, isTrue);
    expect(await source.readAccessToken(), 'fresh-token');
  });

  test('過期時用 refresh_token 換新並寫回本機檔', () async {
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'old-token',
        'refresh_token': 'refresh-token',
        'expiry_date': DateTime(2026, 6, 8).millisecondsSinceEpoch,
        'scope': 'openid',
      }),
    );
    final adapter = _JsonAdapter({
      'access_token': 'new-token',
      'expires_in': 3600,
    });
    final source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = adapter,
      credentialFile: creds,
    );

    expect(await source.isAvailable, isTrue);
    expect(await source.readAccessToken(), 'new-token');
    expect(adapter.posted, isTrue);

    final written = jsonDecode(await creds.readAsString()) as Map;
    expect(written['access_token'], 'new-token');
    expect(written['refresh_token'], 'refresh-token');
    expect(written['scope'], 'openid');
    expect(written['expiry_date'], isA<int>());
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        written['expiry_date'] as int,
      ).isAfter(DateTime.now().add(const Duration(minutes: 30))),
      isTrue,
    );
  });

  test('沒有 refresh_token 且 access 已過期時視為不可用', () async {
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'old-token',
        'expiry_date': DateTime(2026, 6, 8).millisecondsSinceEpoch,
      }),
    );
    final source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = _FailAdapter(),
      credentialFile: creds,
    );

    expect(await source.isAvailable, isFalse);
    expect(await source.readAccessToken(), isNull);
  });

  test('目錄識別隔離帳號與 project，短期 token 變更不影響識別', () async {
    final credential = <String, dynamic>{
      'access_token': 'first-access',
      'refresh_token': 'account-refresh',
      'email': 'first@example.invalid',
      'project_id': 'project-one',
      'expiry_date': DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    };
    await creds.writeAsString(jsonEncode(credential));
    final source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = _FailAdapter(),
      credentialFile: creds,
    );
    expect(source.catalogIdentity, isNull);
    await source.getAuthData();
    final first = source.catalogIdentity;
    expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
    credential['access_token'] = 'rotated-access';
    await creds.writeAsString(jsonEncode(credential));
    await source.getAuthData();
    expect(source.catalogIdentity, first);
    credential['email'] = 'second@example.invalid';
    await creds.writeAsString(jsonEncode(credential));
    await source.getAuthData();
    final second = source.catalogIdentity;
    expect(second, isNot(first));
    credential['project_id'] = 'project-two';
    await creds.writeAsString(jsonEncode(credential));
    await source.getAuthData();
    expect(source.catalogIdentity, isNot(second));
    await creds.delete();
    expect(await source.getAuthData(), isNull);
    expect(source.catalogIdentity, isNull);
  });

  test('目錄識別在 refresh token 輪替後保持一致', () async {
    final credential = <String, dynamic>{
      'access_token': 'first-access',
      'refresh_token': 'first-refresh',
      'expiry_date': DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    };
    await creds.writeAsString(jsonEncode(credential));
    final source = AntigravityAuthSource(
      dio: Dio()
        ..httpClientAdapter = _JsonAdapter({
          'access_token': 'next-access',
          'refresh_token': 'next-refresh',
          'expires_in': 3600,
        }),
      credentialFile: creds,
    );
    await source.getAuthData();
    final identity = source.catalogIdentity;
    credential['expiry_date'] = 0;
    await creds.writeAsString(jsonEncode(credential));
    expect((await source.getAuthData())?.accessToken, 'next-access');
    expect(source.catalogIdentity, identity);
    expect((await source.getAuthData())?.accessToken, 'next-access');
    expect(source.catalogIdentity, identity);
  });

  test('無帳號且只有 access token 時保守隔離不同授權', () async {
    final credential = <String, dynamic>{
      'access_token': 'anonymous-first-access',
      'expiry_date': DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    };
    await creds.writeAsString(jsonEncode(credential));
    final source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = _FailAdapter(),
      credentialFile: creds,
    );
    await source.getAuthData();
    final first = source.catalogIdentity;
    credential['access_token'] = 'anonymous-second-access';
    await creds.writeAsString(jsonEncode(credential));
    await source.getAuthData();
    expect(source.catalogIdentity, isNot(first));
  });

  test('A 更新尚未完成時換成 B，B 不共用 A token，晚到 A 不覆蓋 B', () async {
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'old-a',
        'refresh_token': 'refresh-a',
        'project_id': 'project-a',
        'expiry_date': 0,
      }),
    );
    final _HeldAdapter adapter = _HeldAdapter();
    final AntigravityAuthSource source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = adapter,
      credentialFile: creds,
    );
    final Future<AntigravityAuthData?> first = source.getAuthData();
    await adapter.waitForCount(1);
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'old-b',
        'refresh_token': 'refresh-b',
        'project_id': 'project-b',
        'expiry_date': 0,
      }),
    );
    final Future<AntigravityAuthData?> second = source.getAuthData();
    await adapter.waitForCount(2);
    expect(adapter.requests[0].options.data['refresh_token'], 'refresh-a');
    expect(adapter.requests[1].options.data['refresh_token'], 'refresh-b');
    adapter.requests[1].complete({'access_token': 'new-b', 'expires_in': 3600});
    expect(await second, (accessToken: 'new-b', projectId: 'project-b'));
    final String? identityB = source.catalogIdentity;
    adapter.requests[0].complete({
      'access_token': 'late-a',
      'expires_in': 3600,
    });
    expect(await first, isNull);
    final Map<dynamic, dynamic> stored =
        jsonDecode(await creds.readAsString()) as Map;
    expect(stored['access_token'], 'new-b');
    expect(stored['refresh_token'], 'refresh-b');
    expect(stored['project_id'], 'project-b');
    expect(source.catalogIdentity, identityB);
  });

  test('同一授權的並行更新只送一次，refresh token 輪替仍保持識別', () async {
    final Map<String, dynamic> credential = {
      'access_token': 'initial',
      'refresh_token': 'refresh-initial',
      'project_id': 'project',
      'expiry_date': DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    };
    await creds.writeAsString(jsonEncode(credential));
    final _HeldAdapter adapter = _HeldAdapter();
    final AntigravityAuthSource source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = adapter,
      credentialFile: creds,
    );
    await source.getAuthData();
    final String? originalIdentity = source.catalogIdentity;
    credential['expiry_date'] = 0;
    await creds.writeAsString(jsonEncode(credential));
    final Future<AntigravityAuthData?> first = source.getAuthData();
    final Future<AntigravityAuthData?> second = source.getAuthData();
    await adapter.waitForCount(1);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(1));
    adapter.requests.single.complete({
      'access_token': 'updated',
      'refresh_token': 'refresh-rotated',
      'expires_in': 3600,
    });
    expect(await first, (accessToken: 'updated', projectId: 'project'));
    expect(await second, await first);
    expect(source.catalogIdentity, originalIdentity);
    expect((await source.getAuthData())!.accessToken, 'updated');
    expect(source.catalogIdentity, originalIdentity);
    expect(adapter.requests, hasLength(1));
  });

  test('等待更新期間來源憑證被刪除，不重新建立或使用晚到 token', () async {
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'old',
        'refresh_token': 'refresh',
        'expiry_date': 0,
      }),
    );
    final _HeldAdapter adapter = _HeldAdapter();
    final AntigravityAuthSource source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = adapter,
      credentialFile: creds,
    );
    final Future<AntigravityAuthData?> pending = source.getAuthData();
    await adapter.waitForCount(1);
    await creds.delete();
    adapter.requests.single.complete({
      'access_token': 'late',
      'expires_in': 3600,
    });
    expect(await pending, isNull);
    expect(await creds.exists(), isFalse);
  });

  test('目錄識別綁定授權結果，不被後續帳號讀取覆蓋', () async {
    final AntigravityAuthSource source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = _FailAdapter(),
      credentialFile: creds,
    );
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'access-a',
        'refresh_token': 'refresh-a',
        'project_id': 'project-a',
      }),
    );
    final AntigravityAuthData authA = (await source.getAuthData())!;
    final String? identityA = source.catalogIdentity;
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'access-b',
        'refresh_token': 'refresh-b',
        'project_id': 'project-b',
      }),
    );
    final AntigravityAuthData authB = (await source.getAuthData())!;
    final String? identityB = source.catalogIdentity;
    expect(identityA, isNot(identityB));
    expect(source.catalogIdentityFor(authA), identityA);
    expect(source.catalogIdentityFor(authB), identityB);
    expect(
      source.catalogIdentityFor((accessToken: 'unknown', projectId: 'unknown')),
      isNull,
    );
    expect(identityA, isNot(contains('access-a')));
    expect(identityB, isNot(contains('project-b')));
  });

  test('讀檔與更新授權的錯誤日誌不包含憑證或回應全文', () async {
    final List<String> messages = [];
    final DebugPrintCallback originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);
    final AntigravityAuthSource source = AntigravityAuthSource(
      dio: Dio()..httpClientAdapter = _SensitiveErrorAdapter(),
      credentialFile: creds,
    );
    await creds.writeAsString('{"refresh_token":"sensitive-file-content"');
    expect(await source.getAuthData(), isNull);
    await creds.writeAsString(
      jsonEncode({
        'access_token': 'old',
        'refresh_token': 'sensitive-refresh-token',
        'expiry_date': 0,
      }),
    );
    expect(await source.getAuthData(), isNull);
    expect(messages, hasLength(2));
    expect(messages.join('\n'), contains('FormatException'));
    expect(messages.join('\n'), contains('DioException'));
    expect(messages.join('\n'), isNot(contains('sensitive')));
  });
}

class _SensitiveErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'sensitive-server-response',
    );
  }
}

class _PendingAuthRequest {
  _PendingAuthRequest(this.options);

  final RequestOptions options;
  final Completer<ResponseBody> response = Completer<ResponseBody>();

  void complete(Map<String, dynamic> data) {
    response.complete(
      ResponseBody.fromString(
        jsonEncode(data),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }
}

class _HeldAdapter implements HttpClientAdapter {
  final List<_PendingAuthRequest> requests = [];

  Future<void> waitForCount(int count) async {
    for (int attempt = 0; attempt < 200; attempt++) {
      if (requests.length >= count) return;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    fail('等待第 $count 個假授權請求逾時');
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final _PendingAuthRequest pending = _PendingAuthRequest(options);
    requests.add(pending);
    return pending.response.future;
  }
}

class _FailAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw StateError('不應發出網路請求');
  }
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.payload);

  final Map<String, dynamic> payload;
  bool posted = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    posted = true;
    expect(options.uri.toString(), AntigravityAuthSource.tokenUri);
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
