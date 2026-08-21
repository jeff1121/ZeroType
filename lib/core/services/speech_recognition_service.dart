import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

typedef TranscriptionResult = ({
  String text,
  int? inputTokens,
  int? outputTokens,
});

class SpeechRecognitionService {
  SpeechRecognitionService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<TranscriptionResult> transcribe({
    required String audioFilePath,
    required String provider,
    required String model,
    required String prompt,
    required SpeechChannel channel,
    String? apiKey,
    String? accessToken,
    String? antigravityProjectId,
    bool isAntigravity = false,
    String? proxyRoot,
    String? azureEndpoint,
    String? azureApiVersion,
  }) async {
    print(
      '[SpeechRecognition] Transcribing with $provider ($model) via ${channel.id}${isAntigravity ? " (Antigravity Direct)" : ""}',
    );

    switch (provider) {
      case 'openai':
        return _transcribeWithOpenAI(
          audioFilePath: audioFilePath,
          apiKey: apiKey,
          accessToken: accessToken,
          model: model,
          prompt: prompt,
          channel: channel,
          proxyRoot: proxyRoot,
        );
      case 'gemini':
        if (isAntigravity && channel == SpeechChannel.official) {
          return _transcribeWithAntigravityDirect(
            audioFilePath: audioFilePath,
            accessToken: accessToken,
            projectId: antigravityProjectId,
            model: model,
            prompt: prompt,
          );
        }
        return _transcribeWithGemini(
          audioFilePath: audioFilePath,
          apiKey: apiKey,
          accessToken: accessToken,
          model: model,
          prompt: prompt,
          channel: channel,
          proxyRoot: proxyRoot,
        );
      case SpeechConnectionState.azureProviderId:
        return _transcribeWithAzure(
          audioFilePath: audioFilePath,
          apiKey: apiKey,
          model: model,
          prompt: prompt,
          endpoint: azureEndpoint,
          apiVersion: azureApiVersion,
        );
      default:
        throw Exception('不支援的語音辨識服務商：$provider');
    }
  }

  Future<TranscriptionResult> _transcribeWithOpenAI({
    required String audioFilePath,
    required String model,
    required String prompt,
    required SpeechChannel channel,
    String? apiKey,
    String? accessToken,
    String? proxyRoot,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFilePath,
        filename: File(audioFilePath).uri.pathSegments.last,
      ),
      'model': model,
      'response_format': 'json',
      if (prompt.isNotEmpty) 'prompt': prompt,
    });

    final url = channel == SpeechChannel.proxy
        ? '${_normalizeRoot(proxyRoot)}/v1/audio/transcriptions'
        : 'https://api.openai.com/v1/audio/transcriptions';

    final response = await _dio.post<dynamic>(
      url,
      data: formData,
      options: Options(
        headers: _authHeaders(accessToken: accessToken, apiKey: apiKey),
      ),
    );

    Map<String, dynamic>? data;
    if (response.data is Map<String, dynamic>) {
      data = response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      try {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } catch (_) {
        return (
          text: (response.data as String).trim(),
          inputTokens: null,
          outputTokens: null,
        );
      }
    }

    final text = (data?['text'] as String? ?? '').trim();
    final usageMap = data?['usage'] as Map<String, dynamic>?;
    final inputTokens = usageMap?['input_tokens'] as int?;
    final outputTokens = usageMap?['output_tokens'] as int?;

    return (text: text, inputTokens: inputTokens, outputTokens: outputTokens);
  }

  Future<TranscriptionResult> _transcribeWithAzure({
    required String audioFilePath,
    required String model,
    required String prompt,
    String? apiKey,
    String? endpoint,
    String? apiVersion,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('缺少使用中憑證');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFilePath,
        filename: File(audioFilePath).uri.pathSegments.last,
      ),
      'response_format': 'json',
      if (prompt.isNotEmpty) 'prompt': prompt,
    });

    final url = buildAzureTranscriptionUrl(
      endpoint: endpoint,
      deployment: model,
      apiVersion: apiVersion,
    );

    final response = await _dio.post<dynamic>(
      url,
      data: formData,
      options: Options(headers: azureApiKeyHeaders(apiKey)),
    );

    Map<String, dynamic>? data;
    if (response.data is Map<String, dynamic>) {
      data = response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      try {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } catch (_) {
        return (
          text: (response.data as String).trim(),
          inputTokens: null,
          outputTokens: null,
        );
      }
    }

    final text = (data?['text'] as String? ?? '').trim();
    return (text: text, inputTokens: null, outputTokens: null);
  }

  /// Azure Whisper 轉寫 URL：`{endpoint}/openai/deployments/{deployment}/audio/transcriptions?api-version={ver}`
  static String buildAzureTranscriptionUrl({
    required String? endpoint,
    required String deployment,
    required String? apiVersion,
  }) {
    final root = normalizeAzureEndpoint(endpoint);
    if (root.isEmpty) {
      throw Exception('尚未設定 Azure Service Endpoint');
    }
    final deploymentName = deployment.trim();
    if (deploymentName.isEmpty) {
      throw Exception('尚未選擇 Azure 部署');
    }
    final version = (apiVersion ?? '').trim();
    if (version.isEmpty) {
      throw Exception('尚未設定 Azure API Version');
    }
    return '$root/openai/deployments/${Uri.encodeComponent(deploymentName)}/audio/transcriptions?api-version=${Uri.encodeQueryComponent(version)}';
  }

  static Map<String, String> azureApiKeyHeaders(String apiKey) {
    if (apiKey.isEmpty) {
      throw Exception('缺少使用中憑證');
    }
    return {'api-key': apiKey};
  }

  Future<TranscriptionResult> _transcribeWithAntigravityDirect({
    required String audioFilePath,
    required String? accessToken,
    required String? projectId,
    required String model,
    required String prompt,
  }) async {
    print('[AntigravityDirect] Start transcription: $audioFilePath');
    final fileToUpload = File(audioFilePath);
    if (!fileToUpload.existsSync()) {
      throw Exception('找不到音檔：$audioFilePath');
    }

    final mimeType = audioFilePath.endsWith('.m4a')
        ? 'audio/mp4'
        : (audioFilePath.endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4');
    final audioBytes = await fileToUpload.readAsBytes();
    final base64Audio = base64Encode(audioBytes);

    final finalPrompt = prompt.isEmpty
        ? 'Generate a transcript of the speech.'
        : prompt;

    final endpoints = [
      'https://daily-cloudcode-pa.googleapis.com/v1internal:generateContent',
      'https://cloudcode-pa.googleapis.com/v1internal:generateContent',
    ];

    final payload = {
      if (projectId != null && projectId.isNotEmpty) 'project': projectId,
      'model': model,
      'request': {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': finalPrompt},
              {
                'inline_data': {'mime_type': mimeType, 'data': base64Audio},
              },
            ],
          },
        ],
      },
    };

    DioException? lastErr;
    for (final url in endpoints) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          url,
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'User-Agent': 'antigravity/1.0.0 darwin/arm64',
            },
          ),
        );

        final responseObj =
            response.data?['response'] as Map<String, dynamic>? ??
            response.data;
        final candidates = responseObj?['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Antigravity 轉譯失敗：無候選回應');
        }

        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          throw Exception('Antigravity 轉譯失敗：內容為空');
        }

        final text = (parts[0]['text'] as String? ?? '').trim();
        final usageMeta =
            responseObj?['usageMetadata'] as Map<String, dynamic>?;
        final inputTokens = usageMeta?['promptTokenCount'] as int?;
        final outputTokens = usageMeta?['candidatesTokenCount'] as int?;

        print('[AntigravityDirect] Success! text: $text');
        return (
          text: text,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        );
      } on DioException catch (e) {
        lastErr = e;
        print('[AntigravityDirect] Failed on $url: ${e.response?.statusCode}');
      }
    }
    throw lastErr ?? Exception('Antigravity 端點連線失敗');
  }

  Future<TranscriptionResult> _transcribeWithGemini({
    required String audioFilePath,
    required String model,
    required String prompt,
    required SpeechChannel channel,
    String? apiKey,
    String? accessToken,
    String? proxyRoot,
  }) async {
    print('[Gemini] Start direct transcription: $audioFilePath');

    final fileToUpload = File(audioFilePath);
    if (!fileToUpload.existsSync()) {
      throw Exception('找不到音檔：$audioFilePath');
    }

    final mimeType = audioFilePath.endsWith('.m4a')
        ? 'audio/mp4'
        : (audioFilePath.endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4');
    final audioBytes = await fileToUpload.readAsBytes();
    final base64Audio = base64Encode(audioBytes);

    final finalPrompt = prompt.isEmpty
        ? 'Generate a transcript of the speech.'
        : prompt;

    final url = channel == SpeechChannel.proxy
        ? '${_normalizeRoot(proxyRoot)}/v1beta/models/$model:generateContent'
        : 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'contents': [
            {
              'parts': [
                {'text': finalPrompt},
                {
                  'inline_data': {'mime_type': mimeType, 'data': base64Audio},
                },
              ],
            },
          ],
        },
        options: Options(
          headers: {
            ..._authHeaders(
              accessToken: accessToken,
              apiKey: apiKey,
              googleApiKey:
                  channel == SpeechChannel.official && accessToken == null,
            ),
            'Content-Type': 'application/json',
          },
        ),
      );

      final candidates = response.data?['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini 轉譯失敗：無候選回應');
      }

      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Gemini 轉譯失敗：內容為空');
      }

      final text = (parts[0]['text'] as String? ?? '').trim();

      final usageMeta =
          response.data?['usageMetadata'] as Map<String, dynamic>?;
      final inputTokens = usageMeta?['promptTokenCount'] as int?;
      final outputTokens = usageMeta?['candidatesTokenCount'] as int?;

      print('[Gemini] Success! tokens: in=$inputTokens out=$outputTokens');
      return (text: text, inputTokens: inputTokens, outputTokens: outputTokens);
    } on DioException catch (e) {
      print('[Gemini] DioException: ${e.message}');
      print('[Gemini] Status: ${e.response?.statusCode}');
      rethrow;
    }
  }

  Map<String, String> _authHeaders({
    String? accessToken,
    String? apiKey,
    bool googleApiKey = false,
  }) {
    if (accessToken != null && accessToken.isNotEmpty) {
      return {'Authorization': 'Bearer $accessToken'};
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('缺少使用中憑證');
    }
    if (googleApiKey) {
      return {'x-goog-api-key': apiKey};
    }
    return {'Authorization': 'Bearer $apiKey'};
  }

  String _normalizeRoot(String? raw) {
    var root = (raw ?? '').trim();
    if (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    if (root.isEmpty) {
      throw Exception('尚未設定 Proxy 根位址');
    }
    return root;
  }
}
