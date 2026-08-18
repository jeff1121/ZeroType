import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

abstract class ModelConfigRepository {
  Future<ProvidersConfig> loadProvidersConfig();

  Future<String?> getSelectedSpeechProviderId();
  Future<void> saveSelectedSpeechProviderId(String providerId);

  Future<SpeechChannel> getSpeechChannel(String providerId);
  Future<void> saveSpeechChannel(String providerId, SpeechChannel channel);

  Future<String?> getSelectedSpeechModelId(
    String providerId,
    SpeechChannel channel,
  );
  Future<void> saveSelectedSpeechModelId(
    String providerId,
    SpeechChannel channel,
    String modelId,
  );

  Future<String?> getSpeechApiKey(String providerId, SpeechChannel channel);
  Future<void> saveSpeechApiKey(
    String providerId,
    SpeechChannel channel,
    String apiKey,
  );

  Future<String?> getProxyRoot(String providerId);
  Future<void> saveProxyRoot(String providerId, String root);

  Future<CredentialMethod?> getOfficialCredentialMethod(String providerId);
  Future<void> saveOfficialCredentialMethod(
    String providerId,
    CredentialMethod? method,
  );

  Future<GeminiOauthTokens?> getGeminiOauthTokens();
  Future<void> saveGeminiOauthTokens(GeminiOauthTokens tokens);
  Future<void> clearGeminiOauthTokens();
}

class GeminiOauthTokens {
  const GeminiOauthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiry,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiry;

  bool get isAccessTokenFresh =>
      expiry.isAfter(DateTime.now().add(const Duration(seconds: 60)));
}
