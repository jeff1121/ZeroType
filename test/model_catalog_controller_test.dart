import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/services/antigravity_auth_source.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';
import 'package:zero_type/core/services/proxy_model_catalog_service.dart';
import 'package:zero_type/features/model_config/data/repositories/model_config_repository_impl.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';
import 'package:zero_type/features/model_config/presentation/controllers/model_catalog_controller.dart';
import 'package:zero_type/features/model_config/presentation/controllers/model_config_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late ModelConfigRepositoryImpl repository;
  late _ControlledTransport transport;
  late _FakeAuthSource authSource;
  ProviderContainer? container;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = ModelConfigRepositoryImpl(prefs: preferences);
    transport = _ControlledTransport();
    final dio = Dio()..httpClientAdapter = transport;
    authSource = _FakeAuthSource();
    getIt.registerSingleton<SharedPreferences>(preferences);
    getIt.registerSingleton<AntigravityAuthSource>(authSource);
    getIt.registerSingleton<OfficialModelCatalogService>(
      OfficialModelCatalogService(dio: dio),
    );
    getIt.registerSingleton<ProxyModelCatalogService>(
      ProxyModelCatalogService(dio: dio),
    );
    await repository.saveSelectedSpeechProviderId('gemini');
    await repository.saveSpeechApiKey(
      'gemini',
      SpeechChannel.official,
      'key-a',
    );
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.apiKey,
    );
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await getIt.reset();
  });

  Future<ModelCatalogController> start() async {
    container = ProviderContainer(
      overrides: [
        providersConfigProvider.overrideWith(
          (ref) async => const ProvidersConfig(
            speechRecognition: [
              AiProvider(
                id: 'gemini',
                name: 'Gemini',
                models: [AiModel(id: 'bundled-gemini', name: 'Bundled Gemini')],
              ),
              AiProvider(
                id: 'openai',
                name: 'OpenAI',
                models: [AiModel(id: 'whisper-1', name: 'Whisper')],
              ),
              AiProvider(id: 'azure', name: 'Azure', models: []),
            ],
          ),
        ),
      ],
    );
    container!.listen(modelCatalogProvider, (_, _) {});
    await container!.read(speechProviderControllerProvider.future);
    await _until(() => container!.read(modelCatalogProvider).scopeKey != null);
    return container!.read(modelCatalogProvider.notifier);
  }

  Future<ModelCatalogState> settle() async {
    await _until(() => !container!.read(modelCatalogProvider).isRefreshing);
    return container!.read(modelCatalogProvider);
  }

  Future<void> switchProvider(String provider) async {
    await container!
        .read(speechProviderControllerProvider.notifier)
        .selectProvider(provider);
    await container!.read(speechProviderControllerProvider.future);
  }

  test('真實目錄傳輸保留同名不同 ID，重新整理不累加，合法空清單不 fallback', () async {
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests[0].complete(
      _gemini([
        ('flash-b', 'Gemini Flash Lite'),
        ('flash-a', 'Gemini Flash Lite'),
        ('flash-a', 'Gemini Flash Lite'),
      ]),
    );
    final first = await settle();
    expect(first.source, CatalogSource.remote);
    expect(first.models.map((model) => model.id), ['flash-a', 'flash-b']);
    expect(first.models.map((model) => model.name).toSet(), {
      'Gemini Flash Lite',
    });
    final reload = controller.refresh();
    await transport.waitForCount(2);
    transport.requests[1].complete(_gemini([('flash-b', 'Gemini Flash Lite')]));
    expect((await reload)!.models.map((model) => model.id), ['flash-b']);
    final empty = controller.refresh();
    await transport.waitForCount(3);
    transport.requests[2].complete({'models': []});
    final result = (await empty)!;
    expect(result.source, CatalogSource.remote);
    expect(result.models, isEmpty);
    expect(result.failure, isNull);
    expect(result.refreshMessage, contains('沒有可列出的模型'));
  });

  test('連續按更新共用 Future 與傳輸請求', () async {
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete(_gemini([('initial', 'Initial')]));
    await settle();
    final first = controller.refresh();
    final second = controller.refresh();
    expect(identical(first, second), isTrue);
    await transport.waitForCount(2);
    transport.requests[1].complete(_gemini([('updated', 'Updated')]));
    expect((await first)!.models.single.id, 'updated');
    expect(await second, same(await first));
    expect(transport.requests, hasLength(2));
  });

  test('Antigravity 授權尚在等待時連點，共用授權與目錄請求', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    authSource.authGate = Completer<void>();
    final controller = await start();
    await _until(() => authSource.authReads == 1);
    final first = controller.refresh();
    final second = controller.refresh();
    expect(identical(first, second), isTrue);
    expect(authSource.authReads, 1);
    expect(transport.requests, isEmpty);
    authSource.authGate!.complete();
    await transport.waitForCount(1);
    transport.requests.first.complete({'models': {}});
    expect((await first)!.source, CatalogSource.remote);
    expect(await second, same(await first));
    expect(authSource.authReads, 1);
    expect(transport.requests, hasLength(1));
  });

  test('成功取得的空目錄也能快取，後續失敗不冒出內建模型', () async {
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({'models': []});
    await settle();
    final reload = controller.refresh();
    await transport.waitForCount(2);
    transport.requests[1].complete({}, statusCode: 503);
    final result = (await reload)!;
    expect(result.source, CatalogSource.cache);
    expect(result.models, isEmpty);
    expect(result.failure?.kind, CatalogFailureKind.server);
  });

  test('Controller 已釋放後完成的請求安全忽略，沒有可供 UI 顯示的通知', () async {
    final controller = await start();
    await transport.waitForCount(1);
    final pending = controller.refresh();
    container!.dispose();
    container = null;
    transport.requests.first.complete(_gemini([('late', 'Late')]));
    expect(await pending, isNull);
  });

  test('查詢失敗保留同情境快取與取得時間，訊息不宣稱更新成功', () async {
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete(_gemini([('saved', 'Saved')]));
    final initial = await settle();
    final reload = controller.refresh();
    await transport.waitForCount(2);
    transport.requests[1].complete({
      'error': 'secret-server-detail',
    }, statusCode: 503);
    final failed = (await reload)!;
    expect(failed.source, CatalogSource.cache);
    expect(failed.models.single.id, 'saved');
    expect(failed.fetchedAt, initial.fetchedAt);
    expect(failed.failure?.kind, CatalogFailureKind.server);
    expect(failed.refreshMessage, contains('更新失敗'));
    expect(failed.refreshMessage, isNot(contains('secret-server-detail')));
    expect(failed.refreshMessage, isNot(contains('已更新')));
  });

  test('第一次失敗使用內建；不同 API Key 不沿用舊快取', () async {
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete(_gemini([('private-a', 'Private A')]));
    final first = await settle();
    await container!
        .read(speechProviderControllerProvider.notifier)
        .saveApiKey('key-b');
    await container!.read(speechProviderControllerProvider.future);
    final reload = controller.refresh();
    await transport.waitForCount(2);
    expect(container!.read(modelCatalogProvider).models, isEmpty);
    transport.requests[1].complete({'error': 'invalid key'}, statusCode: 401);
    final second = (await reload)!;
    expect(second.scopeKey, isNot(first.scopeKey));
    expect(second.source, CatalogSource.bundled);
    expect(second.models.single.id, 'bundled-gemini');
    expect(second.failure?.kind, CatalogFailureKind.unauthorized);
    expect(second.scopeKey, isNot(contains('key-b')));
  });

  test('A 慢請求切 B 再切 A，舊 A/B 回應不覆蓋最新 A 且不回傳通知', () async {
    await repository.saveSpeechApiKey(
      'openai',
      SpeechChannel.official,
      'openai-key',
    );
    await repository.saveOfficialCredentialMethod(
      'openai',
      CredentialMethod.apiKey,
    );
    final controller = await start();
    await transport.waitForCount(1);
    final oldA = controller.refresh();
    await switchProvider('openai');
    final oldB = controller.refresh();
    await transport.waitForCount(2);
    await switchProvider('gemini');
    final newA = controller.refresh();
    await transport.waitForCount(3);
    transport.requests[2].complete(_gemini([('new-a', 'New A')]));
    expect((await newA)!.models.single.id, 'new-a');
    transport.requests[0].complete(_gemini([('stale-a', 'Stale A')]));
    transport.requests[1].complete({
      'data': [
        {'id': 'whisper-stale-b'},
      ],
    });
    expect(await oldA, isNull);
    expect(await oldB, isNull);
    expect(container!.read(modelCatalogProvider).models.single.id, 'new-a');
    expect(transport.requests, hasLength(3));
  });

  test('選模型只寫選取值，不重新查目錄或讀取 OAuth 狀態', () async {
    await start();
    await transport.waitForCount(1);
    transport.requests.first.complete(_gemini([('selected', 'Selected')]));
    final initial = await settle();
    final availabilityReads = authSource.availabilityReads;
    final authReads = authSource.authReads;
    await container!
        .read(speechProviderControllerProvider.notifier)
        .selectModel('selected');
    await Future<void>.delayed(Duration.zero);
    expect(transport.requests, hasLength(1));
    expect(authSource.availabilityReads, availabilityReads);
    expect(authSource.authReads, authReads);
    expect(container!.read(modelCatalogProvider), same(initial));
    expect(
      await repository.getSelectedSpeechModelId(
        'gemini',
        SpeechChannel.official,
      ),
      'selected',
    );
    expect(
      container!.read(speechProviderControllerProvider).value!.modelId,
      'selected',
    );
  });

  test('Antigravity 授權失效且來源未清除舊身分時，選模型仍不重新查授權', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    authSource.authAvailable = false;
    await start();
    final initial = await settle();
    final authReads = authSource.authReads;
    expect(initial.failure?.kind, CatalogFailureKind.unauthorized);
    await container!
        .read(speechProviderControllerProvider.notifier)
        .selectModel(initial.models.first.id);
    await Future<void>.delayed(Duration.zero);
    expect(authSource.authReads, authReads);
    expect(transport.requests, isEmpty);
    expect(container!.read(modelCatalogProvider), same(initial));
  });

  test('Antigravity 缺少來源識別時，選模型不因保守隔離代號再查目錄', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    authSource.exposesIdentity = false;
    await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({
      'models': {
        'selected': {'displayName': 'Selected'},
      },
    });
    final initial = await settle();
    final authReads = authSource.authReads;
    await container!
        .read(speechProviderControllerProvider.notifier)
        .selectModel('selected');
    await Future<void>.delayed(Duration.zero);
    expect(authSource.authReads, authReads);
    expect(transport.requests, hasLength(1));
    expect(container!.read(modelCatalogProvider), same(initial));
  });

  test('Antigravity 失效後再次更新，不以殘留身分暫時恢復舊帳號快取', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({
      'models': {
        'old-private-model': {'displayName': 'Old private model'},
      },
    });
    await settle();
    authSource.authAvailable = false;
    final failed = (await controller.refresh())!;
    expect(failed.source, CatalogSource.bundled);
    final readsBeforeRetry = authSource.authReads;
    authSource.authGate = Completer<void>();
    final retry = controller.refresh();
    await _until(() => authSource.authReads > readsBeforeRetry);
    final loading = container!.read(modelCatalogProvider);
    expect(loading.isRefreshing, isTrue);
    expect(loading.scopeKey, failed.scopeKey);
    expect(loading.source, CatalogSource.bundled);
    expect(loading.models, failed.models);
    expect(
      loading.models.map((model) => model.id),
      isNot(contains('old-private-model')),
    );
    authSource.authGate!.complete();
    expect((await retry)!.failure?.kind, CatalogFailureKind.unauthorized);
    expect(transport.requests, hasLength(1));
  });

  test('未選憑證不送 HTTP，提供明確提示而非更新成功', () async {
    await repository.saveSpeechApiKey('gemini', SpeechChannel.official, '');
    await repository.saveOfficialCredentialMethod('gemini', null);
    final controller = await start();
    await settle();
    final result = (await controller.refresh())!;
    expect(transport.requests, isEmpty);
    expect(result.source, CatalogSource.bundled);
    expect(result.refreshMessage, contains('請先選擇使用中憑證'));
    expect(result.refreshMessage, isNot(contains('已更新')));
  });

  test('Antigravity 全端點失敗明示內建，未使用 Gemini API Key 內建清單', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({}, statusCode: 503);
    await transport.waitForCount(2);
    transport.requests[1].complete({}, statusCode: 503);
    final result = await settle();
    expect(result.source, CatalogSource.bundled);
    expect(
      result.models.map((model) => model.id),
      isNot(contains('bundled-gemini')),
    );
    expect(result.models, isNotEmpty);
    expect(result.failure?.kind, CatalogFailureKind.server);
    expect(result.refreshMessage, contains('更新失敗'));
  });

  test('Antigravity 外部帳號更換後，更新失敗不能沿用前帳號快取', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({
      'models': {
        'account-a-model': {'displayName': 'Account A'},
      },
    });
    final first = await settle();
    authSource.nextIdentity = 'account-b';
    final reload = controller.refresh();
    await transport.waitForCount(2);
    expect(container!.read(modelCatalogProvider).models, isEmpty);
    transport.requests[1].complete({}, statusCode: 503);
    await transport.waitForCount(3);
    transport.requests[2].complete({}, statusCode: 503);
    final second = (await reload)!;
    expect(second.scopeKey, isNot(first.scopeKey));
    expect(second.source, CatalogSource.bundled);
    expect(
      second.models.map((model) => model.id),
      isNot(contains('account-a-model')),
    );
  });

  test('Antigravity 憑證失效不轉用已存 API Key 或其他憑證快取', () async {
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({
      'models': {
        'account-a-model': {'displayName': 'Account A'},
      },
    });
    await settle();
    authSource.authAvailable = false;
    final result = (await controller.refresh())!;
    expect(transport.requests, hasLength(1));
    expect(result.source, CatalogSource.bundled);
    expect(result.failure?.kind, CatalogFailureKind.unauthorized);
    expect(
      result.models.map((model) => model.id),
      isNot(contains('account-a-model')),
    );
    expect(
      container!
          .read(speechProviderControllerProvider)
          .value!
          .activeCredentialMethod,
      CredentialMethod.antigravityOauth,
    );
  });

  test('Proxy 根位址改變立即隔離，失敗不借用官方或舊根位址的目錄', () async {
    await repository.saveSpeechChannel('gemini', SpeechChannel.proxy);
    await repository.saveProxyRoot('gemini', 'https://proxy-a.invalid');
    final controller = await start();
    await transport.waitForCount(1);
    transport.requests.first.complete({
      'data': [
        {'id': 'proxy-a-model'},
      ],
    });
    final first = await settle();
    await container!
        .read(speechProviderControllerProvider.notifier)
        .saveProxyRoot('https://proxy-b.invalid');
    await container!.read(speechProviderControllerProvider.future);
    final reload = controller.refresh();
    await transport.waitForCount(2);
    expect(container!.read(modelCatalogProvider).models, isEmpty);
    transport.requests[1].complete({}, statusCode: 503);
    final second = (await reload)!;
    expect(second.scopeKey, isNot(first.scopeKey));
    expect(second.source, CatalogSource.none);
    expect(second.models, isEmpty);
    expect(second.refreshMessage, contains('更新失敗'));
  });
}

Map<String, Object> _gemini(List<(String, String)> models) => {
  'models': [
    for (final model in models)
      {
        'name': 'models/${model.$1}',
        'displayName': model.$2,
        'supportedGenerationMethods': ['generateContent'],
      },
  ],
};

Future<void> _until(bool Function() condition) async {
  for (int attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('等待非同步狀態超過 100 個事件循環');
}

class _FakeAuthSource extends AntigravityAuthSource {
  _FakeAuthSource()
    : super(dio: Dio()..httpClientAdapter = _ControlledTransport());
  int availabilityReads = 0;
  int authReads = 0;
  String identity = 'account-a';
  String nextIdentity = 'account-a';
  Completer<void>? authGate;
  bool authAvailable = true;
  bool exposesIdentity = true;

  @override
  String? get catalogIdentity => exposesIdentity ? identity : null;

  @override
  Future<bool> get isAvailable async {
    availabilityReads++;
    return true;
  }

  @override
  Future<AntigravityAuthData?> getAuthData() async {
    authReads++;
    await authGate?.future;
    if (!authAvailable) return null;
    identity = nextIdentity;
    return (accessToken: 'test-access-token', projectId: 'test-project');
  }
}

class _PendingRequest {
  _PendingRequest(this.options);
  final RequestOptions options;
  final Completer<ResponseBody> response = Completer<ResponseBody>();

  void complete(Object data, {int statusCode = 200}) {
    response.complete(
      ResponseBody.fromString(
        jsonEncode(data),
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
  }
}

class _ControlledTransport implements HttpClientAdapter {
  final List<_PendingRequest> requests = [];

  Future<void> waitForCount(int count) =>
      _until(() => requests.length >= count);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final request = _PendingRequest(options);
    requests.add(request);
    return request.response.future;
  }

  @override
  void close({bool force = false}) {}
}
