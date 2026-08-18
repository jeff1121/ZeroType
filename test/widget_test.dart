import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

void main() {
  test('官方通道選 API Key 且模型齊全時視為已完成設定', () {
    const actual = SpeechConnectionState(
      providerId: 'gemini',
      channel: SpeechChannel.official,
      officialModelId: 'gemini-2.5-flash',
      proxyModelId: null,
      officialApiKey: 'test-key',
      proxyApiKey: null,
      proxyRoot: null,
      officialCredentialMethod: CredentialMethod.apiKey,
      geminiOauthConnected: false,
      antigravityAvailable: false,
    );

    expect(actual.isReady, isTrue);
    expect(actual.activeCredentialMethod, CredentialMethod.apiKey);
  });

  test('使用中憑證未選擇時視為尚未完成設定', () {
    const actual = SpeechConnectionState(
      providerId: 'gemini',
      channel: SpeechChannel.official,
      officialModelId: 'gemini-2.5-flash',
      proxyModelId: null,
      officialApiKey: 'test-key',
      proxyApiKey: null,
      proxyRoot: null,
      officialCredentialMethod: null,
      geminiOauthConnected: true,
      antigravityAvailable: true,
    );

    expect(actual.isReady, isFalse);
  });
}
