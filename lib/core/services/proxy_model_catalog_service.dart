import 'package:dio/dio.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';

import 'model_catalog_http.dart';

class ProxyModelCatalogService {
  ProxyModelCatalogService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  String normalizeRoot(String raw) =>
      raw.trim().replaceFirst(RegExp(r'/+$'), '');

  Future<CatalogFetchResult> listModels({
    required String proxyRoot,
    required String apiKey,
  }) async {
    final root = normalizeRoot(proxyRoot);
    if (root.isEmpty) {
      return const CatalogFetchResult.failure(
        CatalogFailure(CatalogFailureKind.invalidResponse),
      );
    }
    try {
      final response = await requestModelCatalog(
        dio: _dio,
        url: '$root/v1/models',
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
      );
      return CatalogFetchResult.success(_parseModels(response.data));
    } catch (error) {
      return CatalogFetchResult.failure(classifyCatalogFailure(error));
    }
  }

  List<AiModel> _parseModels(dynamic data) {
    if (data is Map) {
      final openAi = data['data'];
      if (openAi is List) {
        return normalizeCatalogModels(
          readCatalogList(data, 'data')
              .map((item) {
                final id = readCatalogId(item['id']);
                final dynamic displayName = item['displayName'];
                final String name = displayName is String
                    ? displayName.trim()
                    : '';
                return AiModel(id: id, name: name.isEmpty ? id : name);
              })
              .where((m) => m.id.isNotEmpty),
        );
      }
      final google = data['models'];
      if (google is List) {
        return normalizeCatalogModels(
          readCatalogList(data, 'models')
              .map((item) {
                final raw = readCatalogId(item['name'] ?? item['id']);
                final id = raw.replaceFirst(RegExp(r'^models/'), '');
                final dynamic displayName = item['displayName'];
                final String name = displayName is String
                    ? displayName.trim()
                    : '';
                return AiModel(id: id, name: name.isEmpty ? id : name);
              })
              .where((m) => m.id.isNotEmpty),
        );
      }
    }
    throw const CatalogFailure(CatalogFailureKind.invalidResponse);
  }
}
