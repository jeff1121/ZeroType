import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';

import 'support/catalog_test_adapter.dart';

void main() {
  late OfficialModelCatalogService catalog;

  setUp(() {
    catalog = OfficialModelCatalogService(dio: Dio());
  });

  test('Gemini 目錄只保留 generateContent，並去掉嵌入／圖片／TTS', () {
    final models = catalog.parseGeminiModels({
      'models': [
        {
          'name': 'models/gemini-2.5-flash',
          'displayName': 'Gemini 2.5 Flash',
          'supportedGenerationMethods': ['generateContent', 'countTokens'],
        },
        {
          'name': 'models/gemini-embedding-001',
          'displayName': 'Gemini Embedding',
          'supportedGenerationMethods': ['embedContent'],
        },
        {
          'name': 'models/imagen-4.0-generate',
          'displayName': 'Imagen 4',
          'supportedGenerationMethods': ['predict'],
        },
        {
          'name': 'models/gemini-2.5-flash-preview-tts',
          'displayName': 'Gemini 2.5 Flash TTS',
          'supportedGenerationMethods': ['generateContent'],
        },
        {
          'name': 'models/gemini-3-flash-preview',
          'displayName': 'Gemini 3 Flash Preview',
          'supportedGenerationMethods': ['generateContent'],
        },
      ],
    });

    expect(models.map((m) => m.id).toList(), [
      'gemini-2.5-flash',
      'gemini-3-flash-preview',
    ]);
    expect(models.first.name, 'Gemini 2.5 Flash');
  });

  test('OpenAI 目錄只保留轉寫相關模型', () {
    final models = catalog.parseOpenAiModels({
      'data': [
        {'id': 'gpt-4o'},
        {'id': 'gpt-4o-transcribe'},
        {'id': 'whisper-1'},
        {'id': 'dall-e-3'},
        {'id': 'gpt-4o-mini-transcribe'},
      ],
    });

    expect(models.map((m) => m.id).toList(), [
      'gpt-4o-mini-transcribe',
      'gpt-4o-transcribe',
      'whisper-1',
    ]);
  });

  test('Antigravity 目錄解析 API 回應並過濾內部模型', () {
    final models = catalog.parseAntigravityModels({
      'models': {
        'gemini-3.1-flash-lite': {'displayName': 'Gemini 3.1 Flash Lite'},
        'gemini-3.6-flash-high': {'displayName': 'Gemini 3.6 Flash (High)'},
        'tab_flash_lite_preview': {'displayName': 'Tab Internal'},
        'chat_20706': {'displayName': 'Chat Internal'},
        'gemini-3-flash': {'displayName': ''},
      },
    });

    expect(models.map((m) => m.id).toList(), [
      'gemini-3.1-flash-lite',
      'gemini-3.6-flash-high',
      'gemini-3-flash',
    ]);
    expect(models[0].name, 'Gemini 3.1 Flash Lite');
    expect(models[1].name, 'Gemini 3.6 Flash (High)');
    expect(models[2].name, 'gemini-3-flash');
  });

  test('Antigravity 異常格式與合法空清單不同', () {
    for (final Object? invalid in <Object?>[
      null,
      'invalid',
      <String, dynamic>{'models': null},
      <String, dynamic>{
        'models': <dynamic>[42],
      },
    ]) {
      expect(
        () => catalog.parseAntigravityModels(invalid),
        throwsA(isA<CatalogFailure>()),
      );
    }
    expect(catalog.parseAntigravityModels({'models': {}}), isEmpty);
    expect(catalog.parseAntigravityModels({'models': []}), isEmpty);
  });

  test('去識別目錄重播保留五個同名 ID，依 MIME 辨識三種能力', () async {
    // 依已核對的 API 欄位重建，沒有帳號、project、token 或額度資訊。
    final Object? fixture = jsonDecode(
      File('test/fixtures/antigravity_catalog.json').readAsStringSync(),
    );
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      CatalogReply.json(fixture),
    ]);
    final OfficialModelCatalogService service = OfficialModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    );
    final CatalogFetchResult result = await service.listModels(
      providerId: 'gemini',
      isAntigravity: true,
      accessToken: 'fixture-token',
      projectId: 'fixture-project',
    );
    expect(result.isSuccess, isTrue);
    expect(result.models, hasLength(10));
    final List<AiModel> sameName = result.models
        .where((AiModel model) => model.name == 'Gemini 3.5 Flash Lite')
        .toList();
    expect(sameName.map((AiModel model) => model.id), [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.5-flash-thinking',
      'gemini-3.1-flash-lite',
      'gemini-3.5-flash-lite',
    ]);
    expect(
      sameName.every(
        (AiModel model) => model.speechSupport == ModelSpeechSupport.supported,
      ),
      isTrue,
    );
    final Map<String, AiModel> byId = {
      for (final AiModel model in result.models) model.id: model,
    };
    for (final String id in ['claude-sonnet-4-6', 'claude-opus-4-6-thinking']) {
      expect(byId[id]!.speechSupport, ModelSpeechSupport.unsupported);
      expect(byId[id]!.supportedMimeTypes, contains('image/jpeg'));
    }
    for (final String id in ['gemini-3.1-flash-image', 'gpt-oss-120b-medium']) {
      expect(byId[id]!.speechSupport, ModelSpeechSupport.unknown);
      expect(byId[id]!.supportedMimeTypes, isNull);
    }
    expect(byId['gemini-3.8-flash-tiered']!.name, 'gemini-3.8-flash-tiered');
    expect(
      byId['gemini-3.8-flash-tiered']!.speechSupport,
      ModelSpeechSupport.supported,
    );
    expect(adapter.requests.single.data, {'project': 'fixture-project'});
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer fixture-token',
    );
  });

  test('音訊能力以目前 audio/mp4 為準，缺漏或畸形不當作否定', () {
    final List<Object?> inputs = [
      null,
      {},
      [],
      {'audio/mp4': 'true'},
      {'audio/mp4': true, 'image/png': 1},
    ];
    for (final Object? input in inputs) {
      final AiModel model = catalog.parseAntigravityModels({
        'models': {
          'model': {'supportedMimeTypes': input},
        },
      }).single;
      expect(model.speechSupport, ModelSpeechSupport.unknown);
      expect(model.supportedMimeTypes, isNull);
    }
    final List<AiModel> models = catalog.parseAntigravityModels({
      'models': [
        {
          'id': 'mpeg-only',
          'supportedMimeTypes': {'audio/mp4': false, 'audio/mpeg': true},
        },
        {
          'id': 'mp4',
          'supportedMimeTypes': {'audio/mp4': true},
        },
        {
          'id': 'mp4',
          'supportedMimeTypes': {'audio/mp4': true},
        },
      ],
    });
    expect(models, hasLength(2));
    expect(models.first.id, 'mp4');
    expect(models.first.speechSupport, ModelSpeechSupport.supported);
    expect(models.last.speechSupport, ModelSpeechSupport.unsupported);
  });

  test('Antigravity 服務失敗試備援，備援成功也可為空清單', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({'error': '不可顯示的伺服器內容'}, statusCode: 503),
      const CatalogReply.json({'models': {}}),
    ]);
    final CatalogFetchResult result =
        await OfficialModelCatalogService(
          dio: Dio()..httpClientAdapter = adapter,
        ).listModels(
          providerId: 'gemini',
          isAntigravity: true,
          accessToken: 'token',
        );
    expect(result.isSuccess, isTrue);
    expect(result.models, isEmpty);
    expect(adapter.requests.map((RequestOptions request) => request.uri.host), [
      'daily-cloudcode-pa.googleapis.com',
      'cloudcode-pa.googleapis.com',
    ]);
  });

  test('Antigravity 第一個成功空目錄不改用備援或內建', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({'models': {}}),
    ]);
    final CatalogFetchResult result =
        await OfficialModelCatalogService(
          dio: Dio()..httpClientAdapter = adapter,
        ).listModels(
          providerId: 'gemini',
          isAntigravity: true,
          accessToken: 'token',
        );
    expect(result.isSuccess, isTrue);
    expect(result.models, isEmpty);
    expect(adapter.requests, hasLength(1));
  });

  test('Antigravity 兩端格式錯誤回傳失敗，不偽裝成功或內建清單', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({'error': 'wrong-shape'}),
      const CatalogReply.json({'models': null}),
    ]);
    final CatalogFetchResult result =
        await OfficialModelCatalogService(
          dio: Dio()..httpClientAdapter = adapter,
        ).listModels(
          providerId: 'gemini',
          isAntigravity: true,
          accessToken: 'token',
        );
    expect(result.isSuccess, isFalse);
    expect(result.models, isEmpty);
    expect(result.failure!.kind, CatalogFailureKind.invalidResponse);
    expect(adapter.requests, hasLength(2));
  });

  for (final MapEntry<int, CatalogFailureKind> entry in {
    401: CatalogFailureKind.unauthorized,
    403: CatalogFailureKind.forbidden,
    429: CatalogFailureKind.rateLimited,
    503: CatalogFailureKind.server,
  }.entries) {
    test('Antigravity HTTP ${entry.key} 分類且不外洩回應', () async {
      final CatalogTestAdapter adapter = CatalogTestAdapter([
        CatalogReply.json({
          'secret': 'sensitive-response',
        }, statusCode: entry.key),
        CatalogReply.json({
          'secret': 'sensitive-response',
        }, statusCode: entry.key),
      ]);
      final CatalogFetchResult result =
          await OfficialModelCatalogService(
            dio: Dio()..httpClientAdapter = adapter,
          ).listModels(
            providerId: 'gemini',
            isAntigravity: true,
            accessToken: 'token',
          );
      expect(result.failure!.kind, entry.value);
      expect(result.failure!.statusCode, entry.key);
      expect(result.failure.toString(), isNot(contains('sensitive-response')));
      expect(result.failure.toString(), isNot(contains('token')));
      expect(adapter.requests, hasLength(entry.key == 503 ? 2 : 1));
    });
  }

  for (final DioExceptionType timeout in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('Antigravity $timeout 回傳逾時', () async {
      final CatalogTestAdapter adapter = CatalogTestAdapter([
        CatalogReply.error(timeout),
        CatalogReply.error(timeout),
      ]);
      final CatalogFetchResult result =
          await OfficialModelCatalogService(
            dio: Dio()..httpClientAdapter = adapter,
          ).listModels(
            providerId: 'gemini',
            isAntigravity: true,
            accessToken: 'token',
          );
      expect(result.failure!.kind, CatalogFailureKind.timeout);
      expect(adapter.requests, hasLength(2));
    });
  }

  test('缺少 Antigravity 憑證不打網路、不回內建成功', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([]);
    final CatalogFetchResult result = await OfficialModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    ).listModels(providerId: 'gemini', isAntigravity: true);
    expect(result.failure!.kind, CatalogFailureKind.unauthorized);
    expect(adapter.requests, isEmpty);
    expect(
      OfficialModelCatalogService.antigravityModels.every(
        (AiModel model) => model.speechSupport == ModelSpeechSupport.unknown,
      ),
      isTrue,
    );
  });

  test('Gemini 分頁會合併 ID，仍採官方 generateContent 規則', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({
        'models': [
          {
            'name': 'models/gemini-b',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
        'nextPageToken': 'second',
      }),
      const CatalogReply.json({
        'models': [
          {'name': 'models/gemini-a'},
          {'name': 'models/gemini-b'},
          {
            'name': 'models/embedding',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      }),
    ]);
    final CatalogFetchResult result = await OfficialModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    ).listModels(providerId: 'gemini', apiKey: 'key');
    expect(result.models.map((AiModel model) => model.id), [
      'gemini-a',
      'gemini-b',
    ]);
    expect(
      result.models.every(
        (AiModel model) => model.speechSupport == ModelSpeechSupport.unknown,
      ),
      isTrue,
    );
    expect(adapter.requests.last.queryParameters['pageToken'], 'second');
    expect(adapter.requests.first.headers['x-goog-api-key'], 'key');
  });

  test('Gemini 循環分頁是格式錯誤，不無限查詢', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({'models': [], 'nextPageToken': 'loop'}),
      const CatalogReply.json({'models': [], 'nextPageToken': 'loop'}),
    ]);
    final CatalogFetchResult result = await OfficialModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    ).listModels(providerId: 'gemini', apiKey: 'key');
    expect(result.failure!.kind, CatalogFailureKind.invalidResponse);
    expect(adapter.requests, hasLength(2));
  });

  test('Azure 相容端點備援保留自訂部署且不做能力否定', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({'error': 'unsupported'}, statusCode: 404),
      const CatalogReply.json({'unexpected': []}),
      const CatalogReply.json({
        'data': [
          {'id': 'my-custom-deployment', 'model': 'whisper'},
          {'id': 'other-deployment', 'model': 'gpt-4o'},
        ],
      }),
    ]);
    final CatalogFetchResult result =
        await OfficialModelCatalogService(
          dio: Dio()..httpClientAdapter = adapter,
        ).listModels(
          providerId: 'azure',
          apiKey: 'key',
          azureEndpoint: 'https://resource.invalid',
        );
    expect(result.isSuccess, isTrue);
    expect(result.models, hasLength(2));
    expect(
      result.models.every(
        (AiModel model) => model.speechSupport == ModelSpeechSupport.unknown,
      ),
      isTrue,
    );
    expect(adapter.requests, hasLength(3));
    expect(adapter.requests.last.uri.path, '/openai/v1/models');
    expect(adapter.requests.last.headers['api-key'], 'key');
  });
}
