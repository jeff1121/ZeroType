import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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
