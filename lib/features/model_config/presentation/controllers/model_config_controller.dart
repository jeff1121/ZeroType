import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/services/antigravity_auth_source.dart';
import 'package:zero_type/core/services/antigravity_oauth_service.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';
import 'package:zero_type/core/services/proxy_model_catalog_service.dart';
import 'package:zero_type/features/model_config/data/repositories/model_config_repository_impl.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';
import 'package:zero_type/features/model_config/domain/repositories/model_config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'model_config_controller.g.dart';

ModelConfigRepository _buildRepository() =>
    ModelConfigRepositoryImpl(prefs: getIt<SharedPreferences>());

@riverpod
Future<ProvidersConfig> providersConfig(Ref ref) async {
  final repo = _buildRepository();
  return repo.loadProvidersConfig();
}

@riverpod
class SpeechProviderController extends _$SpeechProviderController {
  ModelConfigRepository get _repo => _buildRepository();

  @override
  Future<SpeechConnectionState> build() async {
    var providerId = await _repo.getSelectedSpeechProviderId();

    if (providerId == null) {
      final config = await _repo.loadProvidersConfig();
      if (config.speechRecognition.isNotEmpty) {
        providerId = config.speechRecognition.first.id;
        await _repo.saveSelectedSpeechProviderId(providerId);
      }
    }

    final id = providerId ?? '';
    return SpeechConnectionState(
      providerId: providerId,
      channel: await _repo.getSpeechChannel(id),
      officialModelId: await _repo.getSelectedSpeechModelId(
        id,
        SpeechChannel.official,
      ),
      proxyModelId: await _repo.getSelectedSpeechModelId(
        id,
        SpeechChannel.proxy,
      ),
      officialApiKey: await _repo.getSpeechApiKey(id, SpeechChannel.official),
      proxyApiKey: await _repo.getSpeechApiKey(id, SpeechChannel.proxy),
      proxyRoot: await _repo.getProxyRoot(id),
      officialCredentialMethod: await _repo.getOfficialCredentialMethod(id),
      antigravityAvailable: await getIt<AntigravityAuthSource>().isAvailable,
      azureEndpoint: await _repo.getAzureEndpoint(id),
      azureApiVersion: await _repo.getAzureApiVersion(id),
    );
  }

  Future<void> selectProvider(String providerId) async {
    await _repo.saveSelectedSpeechProviderId(providerId);
    if (providerId == SpeechConnectionState.azureProviderId) {
      await _repo.saveSpeechChannel(providerId, SpeechChannel.official);
    }
    ref.invalidateSelf();
  }

  Future<void> selectChannel(SpeechChannel channel) async {
    final state = await future;
    if (state.providerId == null) return;
    final allowed = SpeechConnectionState.allowedChannelsFor(state.providerId);
    if (!allowed.contains(channel)) return;
    await _repo.saveSpeechChannel(state.providerId!, channel);
    ref.invalidateSelf();
  }

  Future<void> selectModel(String modelId) async {
    final state = await future;
    if (state.providerId == null) return;
    await _repo.saveSelectedSpeechModelId(
      state.providerId!,
      state.channel,
      modelId,
    );
    ref.invalidateSelf();
  }

  Future<void> saveApiKey(String apiKey) async {
    final state = await future;
    if (state.providerId == null) return;
    await _repo.saveSpeechApiKey(state.providerId!, state.channel, apiKey);
    if (state.channel == SpeechChannel.official) {
      await _repo.saveOfficialCredentialMethod(
        state.providerId!,
        CredentialMethod.apiKey,
      );
    }
    ref.invalidateSelf();
  }

  Future<void> saveProxyRoot(String root) async {
    final state = await future;
    if (state.providerId == null) return;
    await _repo.saveProxyRoot(state.providerId!, root);
    ref.invalidateSelf();
  }

  Future<void> saveAzureEndpoint(String endpoint) async {
    final state = await future;
    if (state.providerId == null) return;
    await _repo.saveAzureEndpoint(state.providerId!, endpoint);
    ref.invalidateSelf();
  }

  Future<void> saveAzureApiVersion(String apiVersion) async {
    final state = await future;
    if (state.providerId == null) return;
    await _repo.saveAzureApiVersion(state.providerId!, apiVersion);
    ref.invalidateSelf();
  }

  Future<void> selectCredentialMethod(CredentialMethod method) async {
    final state = await future;
    if (state.providerId == null) return;
    if (state.channel != SpeechChannel.official) return;
    await _repo.saveOfficialCredentialMethod(state.providerId!, method);
    ref.invalidateSelf();
  }

  Future<void> loginAntigravityOauth() async {
    final state = await future;
    if (state.providerId == null) return;
    await getIt<AntigravityOauthService>().login();
    await _repo.saveOfficialCredentialMethod(
      state.providerId!,
      CredentialMethod.antigravityOauth,
    );
    ref.invalidateSelf();
  }
}

@riverpod
Future<List<AiModel>> proxyModels(Ref ref) async {
  final connection = await ref.watch(speechProviderControllerProvider.future);
  if (connection.channel != SpeechChannel.proxy) return const [];
  final root = connection.proxyRoot;
  if (root == null || root.isEmpty) return const [];
  try {
    return await getIt<ProxyModelCatalogService>().listModels(
      proxyRoot: root,
      apiKey: connection.proxyApiKey ?? '',
    );
  } catch (e) {
    print('[ProxyModels] 目錄查詢失敗：$e');
    return const [];
  }
}

Duration? _noRetry(int retryCount, Object error) => null;

/// 官方通道即時目錄。尚未有可用憑證或查詢失敗時回傳 null，UI 改用內建清單。
@Riverpod(retry: _noRetry)
Future<List<AiModel>?> officialModels(Ref ref) async {
  final connection = await ref.watch(speechProviderControllerProvider.future);
  if (connection.channel != SpeechChannel.official) return null;
  final providerId = connection.providerId;
  if (providerId == null || providerId.isEmpty) return null;

  final auth = await _resolveCatalogAuth(connection);
  if (auth == null) return null;

  try {
    return await getIt<OfficialModelCatalogService>().listModels(
      providerId: providerId,
      apiKey: auth.apiKey,
      accessToken: auth.accessToken,
      isAntigravity:
          connection.activeCredentialMethod ==
          CredentialMethod.antigravityOauth,
      azureEndpoint: auth.azureEndpoint,
    );
  } catch (e) {
    print('[OfficialModels] 目錄查詢失敗：$e');
    return null;
  }
}

Future<
  ({
    String? apiKey,
    String? accessToken,
    String? azureEndpoint,
    String? azureApiVersion,
  })?
>
_resolveCatalogAuth(SpeechConnectionState connection) async {
  if (connection.isAzure) {
    final key = connection.activeApiKey;
    final endpoint = connection.azureEndpoint;
    if (key == null || key.isEmpty || endpoint == null || endpoint.isEmpty) {
      return null;
    }
    return (
      apiKey: key,
      accessToken: null,
      azureEndpoint: endpoint,
      azureApiVersion: connection.azureApiVersion,
    );
  }
  switch (connection.activeCredentialMethod) {
    case CredentialMethod.apiKey:
      final key = connection.activeApiKey;
      if (key == null || key.isEmpty) return null;
      return (
        apiKey: key,
        accessToken: null,
        azureEndpoint: null,
        azureApiVersion: null,
      );
    case CredentialMethod.antigravityOauth:
      final token = await getIt<AntigravityAuthSource>().readAccessToken();
      if (token == null) return null;
      return (
        apiKey: null,
        accessToken: token,
        azureEndpoint: null,
        azureApiVersion: null,
      );
    case null:
      return null;
  }
}
