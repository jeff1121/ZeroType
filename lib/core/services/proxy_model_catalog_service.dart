import 'package:dio/dio.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';

class ProxyModelCatalogService {
  ProxyModelCatalogService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  String normalizeRoot(String raw) {
    var root = raw.trim();
    if (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    return root;
  }

  Future<List<AiModel>> listModels({
    required String proxyRoot,
    required String apiKey,
  }) async {
    final root = normalizeRoot(proxyRoot);
    if (root.isEmpty) return const [];

    final response = await _dio.get<dynamic>(
      '$root/v1/models',
      options: Options(
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
      ),
    );

    return _parseModels(response.data);
  }

  List<AiModel> _parseModels(dynamic data) {
    if (data is Map<String, dynamic>) {
      final openAi = data['data'];
      if (openAi is List) {
        return openAi
            .whereType<Map>()
            .map((item) {
              final id = item['id']?.toString() ?? '';
              return AiModel(id: id, name: id);
            })
            .where((m) => m.id.isNotEmpty)
            .toList();
      }
      final google = data['models'];
      if (google is List) {
        return google
            .whereType<Map>()
            .map((item) {
              final raw =
                  item['name']?.toString() ?? item['id']?.toString() ?? '';
              final id = raw.replaceFirst(RegExp(r'^models/'), '');
              return AiModel(id: id, name: id);
            })
            .where((m) => m.id.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }
}
