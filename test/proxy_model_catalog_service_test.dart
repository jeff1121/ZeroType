import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/services/proxy_model_catalog_service.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';

import 'support/catalog_test_adapter.dart';

void main() {
  test('Proxy 根位址移除所有結尾斜線且保留服務路徑', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({'data': []}),
    ]);
    final ProxyModelCatalogService service = ProxyModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    );
    expect(
      service.normalizeRoot(' https://proxy.invalid/base/// '),
      'https://proxy.invalid/base',
    );
    final CatalogFetchResult result = await service.listModels(
      proxyRoot: ' https://proxy.invalid/base/// ',
      apiKey: '',
    );
    expect(result.isSuccess, isTrue);
    expect(
      adapter.requests.single.uri.toString(),
      'https://proxy.invalid/base/v1/models',
    );
  });

  test('Proxy 保留自訂 ID 與同名項目，只去除相同 ID', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({
        'data': [
          {'id': 'my-private-z', 'displayName': '同名'},
          {'id': 'my-private-a', 'displayName': '同名'},
          {'id': 'my-private-a', 'displayName': '同名'},
        ],
      }),
    ]);
    final CatalogFetchResult result = await ProxyModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    ).listModels(proxyRoot: 'https://proxy.invalid/', apiKey: 'key');
    expect(result.isSuccess, isTrue);
    expect(result.models.map((AiModel model) => model.id), [
      'my-private-a',
      'my-private-z',
    ]);
    expect(
      result.models.every(
        (AiModel model) => model.speechSupport == ModelSpeechSupport.unknown,
      ),
      isTrue,
    );
    expect(
      adapter.requests.single.uri.toString(),
      'https://proxy.invalid/v1/models',
    );
    expect(adapter.requests.single.sendTimeout, const Duration(seconds: 15));
    expect(adapter.requests.single.receiveTimeout, const Duration(seconds: 15));
  });

  test('Proxy Google 格式保留名稱且正規化 models 前綴', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({
        'models': [
          {'name': 'models/custom-a', 'displayName': 'Friendly name'},
        ],
      }),
    ]);
    final CatalogFetchResult result = await ProxyModelCatalogService(
      dio: Dio()..httpClientAdapter = adapter,
    ).listModels(proxyRoot: 'https://proxy.invalid', apiKey: '');
    expect(result.models.single.id, 'custom-a');
    expect(result.models.single.name, 'Friendly name');
  });

  test('Proxy 合法空清單與錯誤 schema 分開', () async {
    for (final Object response in [
      <String, Object>{'data': []},
      <String, Object>{'models': []},
    ]) {
      final CatalogFetchResult result = await ProxyModelCatalogService(
        dio: Dio()
          ..httpClientAdapter = CatalogTestAdapter([
            CatalogReply.json(response),
          ]),
      ).listModels(proxyRoot: 'https://proxy.invalid', apiKey: '');
      expect(result.isSuccess, isTrue);
      expect(result.models, isEmpty);
    }
    for (final Object? response in [
      null,
      {},
      {'data': null},
      {
        'data': [42],
      },
      {
        'data': [{}],
      },
    ]) {
      final CatalogFetchResult result = await ProxyModelCatalogService(
        dio: Dio()
          ..httpClientAdapter = CatalogTestAdapter([
            CatalogReply.json(response),
          ]),
      ).listModels(proxyRoot: 'https://proxy.invalid', apiKey: '');
      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind, CatalogFailureKind.invalidResponse);
    }
  });

  for (final MapEntry<int, CatalogFailureKind> entry in {
    401: CatalogFailureKind.unauthorized,
    403: CatalogFailureKind.forbidden,
    429: CatalogFailureKind.rateLimited,
    500: CatalogFailureKind.server,
  }.entries) {
    test('Proxy HTTP ${entry.key} 回傳安全分類', () async {
      final CatalogFetchResult result = await ProxyModelCatalogService(
        dio: Dio()
          ..httpClientAdapter = CatalogTestAdapter([
            CatalogReply.json({
              'secret': 'sensitive-response',
            }, statusCode: entry.key),
          ]),
      ).listModels(proxyRoot: 'https://proxy.invalid', apiKey: '');
      expect(result.failure!.kind, entry.value);
      expect(result.failure!.statusCode, entry.key);
      expect(result.failure.toString(), isNot(contains('sensitive-response')));
    });
  }

  test('Proxy timeout 與網路錯誤分開且不偽裝成功', () async {
    for (final MapEntry<DioExceptionType, CatalogFailureKind> entry in {
      DioExceptionType.connectionTimeout: CatalogFailureKind.timeout,
      DioExceptionType.connectionError: CatalogFailureKind.network,
    }.entries) {
      final CatalogFetchResult result = await ProxyModelCatalogService(
        dio: Dio()
          ..httpClientAdapter = CatalogTestAdapter([
            CatalogReply.error(entry.key),
          ]),
      ).listModels(proxyRoot: 'https://proxy.invalid', apiKey: '');
      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind, entry.value);
    }
  });
}
