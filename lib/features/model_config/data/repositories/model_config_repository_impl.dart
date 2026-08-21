import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/constants/app_constants.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';
import 'package:zero_type/features/model_config/domain/repositories/model_config_repository.dart';

class ModelConfigRepositoryImpl implements ModelConfigRepository {
  ModelConfigRepositoryImpl({required SharedPreferences prefs})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  @override
  Future<ProvidersConfig> loadProvidersConfig() async {
    final jsonString = await rootBundle.loadString(
      'assets/config/providers.json',
    );
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    AiProvider parseProvider(Map<String, dynamic> p) => AiProvider(
      id: p['id'] as String,
      name: p['name'] as String,
      models: (p['models'] as List)
          .map((m) => AiModel(id: m['id'] as String, name: m['name'] as String))
          .toList(),
    );

    return ProvidersConfig(
      speechRecognition: (json['speechRecognition'] as List)
          .map((p) => parseProvider(p as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<String?> getSelectedSpeechProviderId() async =>
      _prefs.getString(AppConstants.selectedSpeechProviderKey);

  @override
  Future<void> saveSelectedSpeechProviderId(String providerId) async =>
      _prefs.setString(AppConstants.selectedSpeechProviderKey, providerId);

  @override
  Future<SpeechChannel> getSpeechChannel(String providerId) async {
    final stored = _prefs.getString(_channelKey(providerId));
    if (stored != null) return SpeechChannelX.fromId(stored);

    final legacyEndpoint = _prefs.getString('custom_endpoint_$providerId');
    if (legacyEndpoint != null && legacyEndpoint.trim().isNotEmpty) {
      return SpeechChannel.proxy;
    }
    return SpeechChannel.official;
  }

  @override
  Future<void> saveSpeechChannel(
    String providerId,
    SpeechChannel channel,
  ) async => _prefs.setString(_channelKey(providerId), channel.id);

  @override
  Future<String?> getSelectedSpeechModelId(
    String providerId,
    SpeechChannel channel,
  ) async {
    final keyed = _prefs.getString(_modelKey(providerId, channel));
    if (keyed != null && keyed.isNotEmpty) return keyed;
    if (channel == SpeechChannel.official) {
      return _prefs.getString(
        '${AppConstants.selectedSpeechModelKey}_$providerId',
      );
    }
    return null;
  }

  @override
  Future<void> saveSelectedSpeechModelId(
    String providerId,
    SpeechChannel channel,
    String modelId,
  ) async => _prefs.setString(_modelKey(providerId, channel), modelId);

  @override
  Future<String?> getSpeechApiKey(
    String providerId,
    SpeechChannel channel,
  ) async {
    final keyed = _prefs.getString(_apiKeyKey(providerId, channel));
    if (keyed != null) return keyed;
    return _prefs.getString('api_key_speech_$providerId');
  }

  @override
  Future<void> saveSpeechApiKey(
    String providerId,
    SpeechChannel channel,
    String apiKey,
  ) async => _prefs.setString(_apiKeyKey(providerId, channel), apiKey);

  @override
  Future<String?> getProxyRoot(String providerId) async {
    final stored = _prefs.getString(_proxyRootKey(providerId));
    if (stored != null) return stored;
    return _prefs.getString('custom_endpoint_$providerId');
  }

  @override
  Future<void> saveProxyRoot(String providerId, String root) async =>
      _prefs.setString(_proxyRootKey(providerId), root.trim());

  @override
  Future<CredentialMethod?> getOfficialCredentialMethod(
    String providerId,
  ) async {
    final stored = _prefs.getString(_credentialMethodKey(providerId));
    if (stored != null) return CredentialMethodX.fromId(stored);
    final existingKey = await getSpeechApiKey(
      providerId,
      SpeechChannel.official,
    );
    if (existingKey != null && existingKey.isNotEmpty) {
      return CredentialMethod.apiKey;
    }
    return null;
  }

  @override
  Future<void> saveOfficialCredentialMethod(
    String providerId,
    CredentialMethod? method,
  ) async {
    final key = _credentialMethodKey(providerId);
    if (method == null) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, method.id);
  }

  String _channelKey(String providerId) =>
      '${AppConstants.selectedSpeechChannelKey}_$providerId';

  String _modelKey(String providerId, SpeechChannel channel) =>
      '${AppConstants.selectedSpeechModelKey}_${providerId}_${channel.id}';

  String _apiKeyKey(String providerId, SpeechChannel channel) =>
      'api_key_speech_${providerId}_${channel.id}';

  String _proxyRootKey(String providerId) =>
      '${AppConstants.proxyRootKey}_$providerId';

  String _credentialMethodKey(String providerId) =>
      '${AppConstants.officialCredentialMethodKey}_$providerId';
}
