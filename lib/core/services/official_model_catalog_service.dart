import 'package:dio/dio.dart';
import 'package:zero_type/core/constants/app_constants.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

import 'model_catalog_http.dart';

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

  Future<CatalogFetchResult> listModels({
    required String providerId,
    String? apiKey,
    String? accessToken,
    bool isAntigravity = false,
    String? azureEndpoint,
    String? projectId,
  }) async {
    try {
      final List<AiModel> models;
      if (isAntigravity) {
        models = await _listAntigravity(
          accessToken: accessToken,
          projectId: projectId,
        );
      } else {
        models = switch (providerId) {
          'gemini' => await _listGemini(
            apiKey: apiKey,
            accessToken: accessToken,
          ),
          'openai' => await _listOpenAi(
            apiKey: apiKey,
            accessToken: accessToken,
          ),
          SpeechConnectionState.azureProviderId => await _listAzure(
            apiKey: apiKey,
            endpoint: azureEndpoint,
          ),
          _ => throw const CatalogFailure(CatalogFailureKind.invalidResponse),
        };
      }
      return CatalogFetchResult.success(normalizeCatalogModels(models));
    } catch (error) {
      return CatalogFetchResult.failure(classifyCatalogFailure(error));
    }
  }

  /// 透過 Antigravity API 即時取得目前可用模型列表。
  Future<List<AiModel>> _listAntigravity({
    String? accessToken,
    String? projectId,
  }) async {
    if (accessToken == null || accessToken.isEmpty) {
      throw const CatalogFailure(CatalogFailureKind.unauthorized);
    }
    final endpoints = [
      'https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels',
      'https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels',
    ];
    final payload = {
      if (projectId != null && projectId.isNotEmpty) 'project': projectId,
    };

    CatalogFailure? lastFailure;
    for (final url in endpoints) {
      try {
        final response = await requestModelCatalog(
          dio: _dio,
          url: url,
          method: 'POST',
          data: payload,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'User-Agent': 'antigravity/hub/2.2.1 darwin/arm64',
          },
        );
        return parseAntigravityModels(response.data);
      } on CatalogFailure catch (failure) {
        lastFailure = failure;
        if (!canTryAnotherCatalogEndpoint(failure)) rethrow;
      }
    }
    throw lastFailure ?? const CatalogFailure(CatalogFailureKind.unknown);
  }

  /// 解析 Antigravity 模型目錄回應。
  List<AiModel> parseAntigravityModels(dynamic data) {
    if (data is! Map) {
      throw const CatalogFailure(CatalogFailureKind.invalidResponse);
    }
    final modelsRaw = data['models'];
    final result = <AiModel>[];
    if (modelsRaw is Map) {
      for (final entry in modelsRaw.entries) {
        final id = readCatalogId(entry.key);
        if (id.isEmpty) continue;
        if (id.startsWith('tab_') || id.startsWith('chat_')) continue;
        if (entry.value is! Map) {
          throw const CatalogFailure(CatalogFailureKind.invalidResponse);
        }
        result.add(_antigravityModel(id, entry.value as Map));
      }
    } else if (modelsRaw is List) {
      for (final item in readCatalogList(data, 'models')) {
        final id = readCatalogId(item['id'] ?? item['name']);
        if (id.isEmpty) continue;
        if (id.startsWith('tab_') || id.startsWith('chat_')) continue;
        result.add(_antigravityModel(id, item));
      }
    } else {
      throw const CatalogFailure(CatalogFailureKind.invalidResponse);
    }
    return normalizeCatalogModels(result);
  }

  AiModel _antigravityModel(String id, Map<dynamic, dynamic> item) {
    final dynamic rawDisplayName = item['displayName'];
    final String displayName = rawDisplayName is String
        ? rawDisplayName.trim()
        : '';
    final dynamic rawMimeTypes = item['supportedMimeTypes'];
    final bool hasValidMimeTypes =
        rawMimeTypes is Map &&
        rawMimeTypes.isNotEmpty &&
        rawMimeTypes.entries.every(
          (dynamic entry) =>
              entry.key is String &&
              (entry.key as String).contains('/') &&
              entry.value is bool,
        );
    final Set<String>? mimeTypes = hasValidMimeTypes
        ? Set<String>.unmodifiable(
            rawMimeTypes.entries
                .where((dynamic entry) => entry.value == true)
                .map(
                  (dynamic entry) => (entry.key as String).trim().toLowerCase(),
                ),
          )
        : null;
    final ModelSpeechSupport support = mimeTypes == null
        ? ModelSpeechSupport.unknown
        : mimeTypes.contains('audio/mp4')
        ? ModelSpeechSupport.supported
        : ModelSpeechSupport.unsupported;
    return AiModel(
      id: id,
      name: displayName.isEmpty ? id : displayName,
      speechSupport: support,
      supportReason: switch (support) {
        ModelSpeechSupport.supported => '模型目錄確認支援目前錄音格式（audio/mp4）',
        ModelSpeechSupport.unsupported => '模型目錄未支援目前錄音格式（audio/mp4）',
        ModelSpeechSupport.unknown => '模型目錄未提供可辨識的音訊能力資料',
      },
      supportedMimeTypes: mimeTypes,
    );
  }

  Future<List<AiModel>> _listGemini({
    String? apiKey,
    String? accessToken,
  }) async {
    final models = <AiModel>[];
    final Set<String> visitedPageTokens = <String>{};
    String? pageToken;
    do {
      final response = await requestModelCatalog(
        dio: _dio,
        url: _geminiUrl,
        queryParameters: {'pageSize': 100, 'pageToken': ?pageToken},
        headers: _headers(
          providerId: 'gemini',
          apiKey: apiKey,
          accessToken: accessToken,
        ),
      );
      models.addAll(parseGeminiModels(response.data));
      final dynamic nextPageToken = (response.data as Map)['nextPageToken'];
      if (nextPageToken != null && nextPageToken is! String) {
        throw const CatalogFailure(CatalogFailureKind.invalidResponse);
      }
      pageToken = nextPageToken as String?;
      if (pageToken != null && pageToken.isEmpty) pageToken = null;
      if (pageToken != null && !visitedPageTokens.add(pageToken)) {
        throw const CatalogFailure(CatalogFailureKind.invalidResponse);
      }
    } while (pageToken != null);
    return normalizeCatalogModels(models);
  }

  Future<List<AiModel>> _listOpenAi({
    String? apiKey,
    String? accessToken,
  }) async {
    final response = await requestModelCatalog(
      dio: _dio,
      url: _openAiUrl,
      headers: _headers(
        providerId: 'openai',
        apiKey: apiKey,
        accessToken: accessToken,
      ),
    );
    return parseOpenAiModels(response.data);
  }

  /// 列出 Azure OpenAI 部署與模型，不做 Whisper 過濾。
  /// 依序嘗試：舊 data-plane `/openai/deployments`、`/openai/models` 與 OpenAI 相容端點 `/openai/v1/models`。
  Future<List<AiModel>> _listAzure({String? apiKey, String? endpoint}) async {
    final root = normalizeAzureEndpoint(endpoint);
    if (root.isEmpty) {
      throw const CatalogFailure(CatalogFailureKind.invalidResponse);
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw const CatalogFailure(CatalogFailureKind.unauthorized);
    }
    final urls = [
      azureDeploymentsUrl(root),
      azureModelsUrl(root),
      azureOpenAiCompatModelsUrl(root),
    ];
    CatalogFailure? lastFailure;
    for (final url in urls) {
      try {
        final response = await requestModelCatalog(
          dio: _dio,
          url: url,
          headers: azureApiKeyHeaders(apiKey),
        );
        return parseAzureDeployments(response.data);
      } on CatalogFailure catch (failure) {
        lastFailure = failure;
        if (!canTryAnotherCatalogEndpoint(failure)) rethrow;
      }
    }
    throw lastFailure ?? const CatalogFailure(CatalogFailureKind.unknown);
  }

  static String azureDeploymentsUrl(String endpoint) {
    final root = normalizeAzureEndpoint(endpoint);
    return '$root/openai/deployments?api-version=${AppConstants.azureDeploymentsApiVersion}';
  }

  static String azureModelsUrl(String endpoint) {
    final root = normalizeAzureEndpoint(endpoint);
    return '$root/openai/models?api-version=${AppConstants.defaultAzureApiVersion}';
  }

  static String azureOpenAiCompatModelsUrl(String endpoint) {
    final root = normalizeAzureEndpoint(endpoint);
    return '$root/openai/v1/models';
  }

  static Map<String, String> azureApiKeyHeaders(String apiKey) => {
    'api-key': apiKey,
  };

  /// 解析 Azure 部署清單；以部署名稱當 model id，不過濾。
  List<AiModel> parseAzureDeployments(dynamic data) {
    final raw = readCatalogList(data, 'data');
    return normalizeCatalogModels(
      raw.map((item) {
        final id = readCatalogId(item['id']);
        if (id.isEmpty) return null;
        final model = item['model']?.toString().trim() ?? '';
        final name = (model.isNotEmpty && model != id) ? '$id（$model）' : id;
        return AiModel(id: id, name: name);
      }).whereType<AiModel>(),
    );
  }

  /// 只保留能 generateContent、且不像圖片／嵌入／TTS 的 Gemini 模型。
  List<AiModel> parseGeminiModels(dynamic data) {
    final raw = readCatalogList(data, 'models');
    return normalizeCatalogModels(raw.map(_geminiModel).whereType<AiModel>());
  }

  /// 只保留轉寫相關的 OpenAI 模型。
  List<AiModel> parseOpenAiModels(dynamic data) {
    final raw = readCatalogList(data, 'data');
    return normalizeCatalogModels(
      raw
          .map((item) {
            final id = readCatalogId(item['id']);
            return AiModel(
              id: id,
              name: id,
              speechSupport: ModelSpeechSupport.supported,
              supportReason: 'OpenAI 轉寫模型系列',
            );
          })
          .where((m) => m.id.isNotEmpty && _isOpenAiSpeechModel(m.id)),
    );
  }

  AiModel? _geminiModel(Map item) {
    final raw = readCatalogId(item['name'] ?? item['id']);
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
      throw const CatalogFailure(CatalogFailureKind.unauthorized);
    }
    if (providerId == 'gemini') {
      return {'x-goog-api-key': apiKey};
    }
    return {'Authorization': 'Bearer $apiKey'};
  }
}
