import 'package:dio/dio.dart';
import 'package:zero_type/core/constants/app_constants.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

/// 向 Provider 官方 API 查詢模型目錄。
class OfficialModelCatalogService {
  OfficialModelCatalogService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _openAiUrl = 'https://api.openai.com/v1/models';

  static const _geminiSkipFragments = [
    'embedding',
    'imagen',
    'veo',
    'tts',
    'robot',
    'computer-use',
    'native-audio',
    'image-generation',
    'lyria',
  ];

  static const antigravityModels = [
    AiModel(
      id: 'gemini-3.5-flash-extra-low',
      name: 'Gemini 3.5 Flash (Extra Low)',
    ),
    AiModel(id: 'gemini-3.5-flash-low', name: 'Gemini 3.5 Flash (Low)'),
    AiModel(id: 'gemini-3.6-flash-high', name: 'Gemini 3.6 Flash (High)'),
    AiModel(id: 'gemini-3.7-flash-high', name: 'Gemini 3.7 Flash (High)'),
    AiModel(id: 'gemini-3-flash', name: 'Gemini 3 Flash'),
    AiModel(id: 'gemini-3-flash-agent', name: 'Gemini 3 Flash (Agent)'),
    AiModel(id: 'gemini-3.1-flash-lite', name: 'Gemini 3.1 Flash Lite'),
    AiModel(id: 'gemini-3.1-flash-image', name: 'Gemini 3.1 Flash Image'),
    AiModel(id: 'gemini-3.1-pro-low', name: 'Gemini 3.1 Pro (Low)'),
    AiModel(id: 'gemini-pro-agent', name: 'Gemini Pro (Agent)'),
  ];

  Future<List<AiModel>> listModels({
    required String providerId,
    String? apiKey,
    String? accessToken,
    bool isAntigravity = false,
    String? azureEndpoint,
  }) async {
    if (isAntigravity) {
      return antigravityModels;
    }
    switch (providerId) {
      case 'gemini':
        return _listGemini(apiKey: apiKey, accessToken: accessToken);
      case 'openai':
        return _listOpenAi(apiKey: apiKey, accessToken: accessToken);
      case SpeechConnectionState.azureProviderId:
        return _listAzure(apiKey: apiKey, endpoint: azureEndpoint);
      default:
        return const [];
    }
  }

  Future<List<AiModel>> _listGemini({
    String? apiKey,
    String? accessToken,
  }) async {
    final models = <AiModel>[];
    String? pageToken;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        _geminiUrl,
        queryParameters: {'pageSize': 100, 'pageToken': ?pageToken},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: _headers(
            providerId: 'gemini',
            apiKey: apiKey,
            accessToken: accessToken,
          ),
        ),
      );
      models.addAll(parseGeminiModels(response.data));
      pageToken = response.data?['nextPageToken'] as String?;
      if (pageToken != null && pageToken.isEmpty) pageToken = null;
    } while (pageToken != null);
    return _uniqueById(models);
  }

  Future<List<AiModel>> _listOpenAi({
    String? apiKey,
    String? accessToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _openAiUrl,
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: _headers(
          providerId: 'openai',
          apiKey: apiKey,
          accessToken: accessToken,
        ),
      ),
    );
    return parseOpenAiModels(response.data);
  }

  /// 列出 Azure OpenAI 部署。失敗回傳空清單，不做 Whisper 過濾。
  /// 舊 data-plane `/openai/deployments` 在不少資源已 404，接著改試 `/openai/models`。
  Future<List<AiModel>> _listAzure({String? apiKey, String? endpoint}) async {
    final root = normalizeAzureEndpoint(endpoint);
    if (root.isEmpty || apiKey == null || apiKey.isEmpty) {
      return const [];
    }
    final urls = [azureDeploymentsUrl(root), azureModelsUrl(root)];
    for (final url in urls) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          url,
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: azureApiKeyHeaders(apiKey),
          ),
        );
        final models = parseAzureDeployments(response.data);
        print('[AzureCatalog] 成功 $url（${models.length}）');
        return models;
      } on DioException catch (e) {
        print(
          '[AzureCatalog] ${e.response?.statusCode} $url body=${e.response?.data}',
        );
      } catch (e) {
        print('[AzureCatalog] 失敗 $url：$e');
      }
    }
    return const [];
  }

  static String azureDeploymentsUrl(String endpoint) {
    final root = normalizeAzureEndpoint(endpoint);
    return '$root/openai/deployments?api-version=${AppConstants.azureDeploymentsApiVersion}';
  }

  static String azureModelsUrl(String endpoint) {
    final root = normalizeAzureEndpoint(endpoint);
    return '$root/openai/models?api-version=${AppConstants.defaultAzureApiVersion}';
  }

  static Map<String, String> azureApiKeyHeaders(String apiKey) => {
    'api-key': apiKey,
  };

  /// 解析 Azure 部署清單；以部署名稱當 model id，不過濾。
  List<AiModel> parseAzureDeployments(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final id = item['id']?.toString().trim() ?? '';
          if (id.isEmpty) return null;
          final model = item['model']?.toString().trim() ?? '';
          final name = (model.isNotEmpty && model != id) ? '$id（$model）' : id;
          return AiModel(id: id, name: name);
        })
        .whereType<AiModel>()
        .toList();
  }

  /// 只保留能 generateContent、且不像圖片／嵌入／TTS 的 Gemini 模型。
  List<AiModel> parseGeminiModels(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['models'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(_geminiModel).whereType<AiModel>().toList();
  }

  /// 只保留轉寫相關的 OpenAI 模型。
  List<AiModel> parseOpenAiModels(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final id = item['id']?.toString() ?? '';
          return AiModel(id: id, name: id);
        })
        .where((m) => m.id.isNotEmpty && _isOpenAiSpeechModel(m.id))
        .toList();
  }

  AiModel? _geminiModel(Map item) {
    final raw = item['name']?.toString() ?? item['id']?.toString() ?? '';
    final id = raw.replaceFirst(RegExp(r'^models/'), '');
    if (id.isEmpty || !_isGeminiSpeechModel(id, item)) return null;
    final display = item['displayName']?.toString();
    return AiModel(
      id: id,
      name: (display != null && display.isNotEmpty) ? display : id,
    );
  }

  bool _isGeminiSpeechModel(String id, Map item) {
    final methods = item['supportedGenerationMethods'];
    if (methods is List &&
        methods.isNotEmpty &&
        !methods.map((e) => e.toString()).contains('generateContent')) {
      return false;
    }
    final lower = id.toLowerCase();
    return !_geminiSkipFragments.any(lower.contains);
  }

  bool _isOpenAiSpeechModel(String id) {
    final lower = id.toLowerCase();
    return lower.contains('transcribe') || lower.contains('whisper');
  }

  Map<String, String> _headers({
    required String providerId,
    String? apiKey,
    String? accessToken,
  }) {
    if (accessToken != null && accessToken.isNotEmpty) {
      return {'Authorization': 'Bearer $accessToken'};
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('缺少使用中憑證');
    }
    if (providerId == 'gemini') {
      return {'x-goog-api-key': apiKey};
    }
    return {'Authorization': 'Bearer $apiKey'};
  }

  List<AiModel> _uniqueById(List<AiModel> models) {
    final seen = <String>{};
    return [
      for (final model in models)
        if (seen.add(model.id)) model,
    ];
  }
}
