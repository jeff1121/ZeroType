import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/constants/app_constants.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';
import 'package:zero_type/core/services/speech_recognition_service.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

void main() {
  group('Azure 轉寫 URL / header 組裝', () {
    test('組出 deployments transcriptions URL，並去掉結尾斜線', () {
      final url = SpeechRecognitionService.buildAzureTranscriptionUrl(
        endpoint: 'https://my-res.openai.azure.com/',
        deployment: 'whisper-prod',
        apiVersion: '2024-10-21',
      );

      expect(
        url,
        'https://my-res.openai.azure.com/openai/deployments/whisper-prod/audio/transcriptions?api-version=2024-10-21',
      );
    });

    test('部署名稱含特殊字元時會做 URL encode', () {
      final url = SpeechRecognitionService.buildAzureTranscriptionUrl(
        endpoint: 'https://my-res.openai.azure.com',
        deployment: 'whisper prod',
        apiVersion: '2024-10-21',
      );

      expect(url.contains('/deployments/whisper%20prod/'), isTrue);
    });

    test('缺少 endpoint、部署或 api-version 時丟出例外', () {
      expect(
        () => SpeechRecognitionService.buildAzureTranscriptionUrl(
          endpoint: '  ',
          deployment: 'whisper',
          apiVersion: '2024-10-21',
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => SpeechRecognitionService.buildAzureTranscriptionUrl(
          endpoint: 'https://x.openai.azure.com',
          deployment: '',
          apiVersion: '2024-10-21',
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => SpeechRecognitionService.buildAzureTranscriptionUrl(
          endpoint: 'https://x.openai.azure.com',
          deployment: 'whisper',
          apiVersion: null,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('認證 header 使用 api-key 而非 Bearer', () {
      expect(SpeechRecognitionService.azureApiKeyHeaders('secret-token'), {
        'api-key': 'secret-token',
      });
      expect(
        () => SpeechRecognitionService.azureApiKeyHeaders(''),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Azure 部署清單', () {
    late OfficialModelCatalogService catalog;

    setUp(() {
      catalog = OfficialModelCatalogService(dio: Dio());
    });

    test('以部署名稱當 model id，不過濾非 Whisper 部署', () {
      final models = catalog.parseAzureDeployments({
        'data': [
          {'id': 'whisper-prod', 'model': 'whisper'},
          {'id': 'gpt-4o', 'model': 'gpt-4o'},
          {'id': '  ', 'model': 'ignored'},
          {'id': 'custom-stt', 'model': 'whisper'},
        ],
      });

      expect(models.map((m) => m.id).toList(), [
        'whisper-prod',
        'gpt-4o',
        'custom-stt',
      ]);
      expect(models.first.name, 'whisper-prod（whisper）');
      expect(models[1].name, 'gpt-4o');
    });

    test('非預期 JSON 回傳空清單', () {
      expect(catalog.parseAzureDeployments(null), isEmpty);
      expect(catalog.parseAzureDeployments(<String, dynamic>{}), isEmpty);
      expect(catalog.parseAzureDeployments('oops'), isEmpty);
    });

    test('部署清單 URL 使用固定 api-version 並正規化 endpoint', () {
      expect(
        OfficialModelCatalogService.azureDeploymentsUrl(
          'https://my-res.openai.azure.com/',
        ),
        'https://my-res.openai.azure.com/openai/deployments?api-version=${AppConstants.azureDeploymentsApiVersion}',
      );
      expect(OfficialModelCatalogService.azureApiKeyHeaders('token'), {
        'api-key': 'token',
      });
    });
  });

  group('SpeechConnectionState Azure isReady', () {
    test('四欄齊全時視為已完成設定，且只允許官方通道', () {
      const actual = SpeechConnectionState(
        providerId: SpeechConnectionState.azureProviderId,
        channel: SpeechChannel.official,
        officialModelId: 'whisper-prod',
        proxyModelId: null,
        officialApiKey: 'azure-key',
        proxyApiKey: null,
        proxyRoot: null,
        officialCredentialMethod: CredentialMethod.apiKey,
        antigravityAvailable: false,
        azureEndpoint: 'https://my-res.openai.azure.com',
        azureApiVersion: '2024-10-21',
      );

      expect(actual.isAzure, isTrue);
      expect(actual.isReady, isTrue);
      expect(actual.allowedChannels, [SpeechChannel.official]);
    });

    test('缺少 endpoint 或 api-version 時尚未完成設定', () {
      const missingEndpoint = SpeechConnectionState(
        providerId: SpeechConnectionState.azureProviderId,
        channel: SpeechChannel.official,
        officialModelId: 'whisper-prod',
        proxyModelId: null,
        officialApiKey: 'azure-key',
        proxyApiKey: null,
        proxyRoot: null,
        officialCredentialMethod: CredentialMethod.apiKey,
        antigravityAvailable: false,
        azureEndpoint: null,
        azureApiVersion: '2024-10-21',
      );
      const missingVersion = SpeechConnectionState(
        providerId: SpeechConnectionState.azureProviderId,
        channel: SpeechChannel.official,
        officialModelId: 'whisper-prod',
        proxyModelId: null,
        officialApiKey: 'azure-key',
        proxyApiKey: null,
        proxyRoot: null,
        officialCredentialMethod: CredentialMethod.apiKey,
        antigravityAvailable: false,
        azureEndpoint: 'https://my-res.openai.azure.com',
        azureApiVersion: '',
      );

      expect(missingEndpoint.isReady, isFalse);
      expect(missingVersion.isReady, isFalse);
    });
  });
}
