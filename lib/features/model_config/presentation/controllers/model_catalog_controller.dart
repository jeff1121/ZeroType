import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/services/antigravity_auth_source.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';
import 'package:zero_type/core/services/proxy_model_catalog_service.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';
import 'model_config_controller.dart';

enum CatalogSource { remote, cache, bundled, none }

/// 目錄只描述可顯示的資料，不決定使用中模型或轉寫是否可執行。
class ModelCatalogState {
  const ModelCatalogState({
    this.models = const [],
    this.isRefreshing = false,
    this.source = CatalogSource.none,
    this.failure,
    this.fetchedAt,
    this.statusMessage = '',
    this.refreshMessage = '',
    this.scopeKey,
  });

  final List<AiModel> models;
  final bool isRefreshing;
  final CatalogSource source;
  final CatalogFailure? failure;
  final DateTime? fetchedAt;
  final String statusMessage;
  final String refreshMessage;

  /// 僅限此記憶體工作階段的代號，不包含憑證、帳號或 endpoint。
  final String? scopeKey;
}

final modelCatalogProvider =
    NotifierProvider<ModelCatalogController, ModelCatalogState>(
      ModelCatalogController.new,
    );

typedef _CatalogScope = ({
  String? providerId,
  SpeechChannel channel,
  String endpoint,
  CredentialMethod? credentialMethod,
  String credentialFingerprint,
  String? authIdentity,
});

class ModelCatalogController extends Notifier<ModelCatalogState> {
  final Map<_CatalogScope, String> _scopeKeys = {};
  final Map<String, ModelCatalogState> _cache = {};
  SpeechConnectionState? _connection;
  _CatalogScope? _scope;
  Future<ModelCatalogState?>? _pending;
  int _generation = 0;

  @override
  ModelCatalogState build() {
    ref.listen(speechProviderControllerProvider, (_, next) {
      _syncConnection(next);
    });
    scheduleMicrotask(() {
      if (ref.mounted) {
        _syncConnection(ref.read(speechProviderControllerProvider));
      }
    });
    return const ModelCatalogState(
      isRefreshing: true,
      statusMessage: '正在載入模型設定',
    );
  }

  /// 同一情境的連續更新共用 Future；離開情境後，舊更新不發出通知。
  Future<ModelCatalogState?> refresh() {
    _syncConnection(
      ref.read(speechProviderControllerProvider),
      startRefresh: false,
    );
    final connection = _connection;
    if (connection == null) return Future.value(null);
    return _pending ?? _startRefresh(connection);
  }

  void _syncConnection(
    AsyncValue<SpeechConnectionState> next, {
    bool startRefresh = true,
  }) {
    final connection = next.isLoading ? null : next.asData?.value;
    if (connection == null) {
      _generation++;
      _pending = null;
      _connection = null;
      _scope = null;
      state = ModelCatalogState(
        isRefreshing: next.isLoading,
        statusMessage: next.hasError ? '無法載入模型設定' : '正在載入模型設定',
      );
      return;
    }
    final scope = _makeScope(
      connection,
      authIdentity:
          connection.activeCredentialMethod == CredentialMethod.antigravityOauth
          ? getIt<AntigravityAuthSource>().catalogIdentity
          : null,
    );
    _connection = connection;
    if (scope == _scope) return;
    // 選模型不重新判讀授權身分；失效授權也不能用殘留身分恢復舊快取。
    if (_hasSameConfiguration(scope) &&
        (startRefresh || _pending != null || _scope!.authIdentity == null)) {
      return;
    }
    _generation++;
    _pending = null;
    _scope = scope;
    state = _loadingState(_keyFor(scope));
    if (startRefresh) unawaited(_startRefresh(connection));
  }

  bool _hasSameConfiguration(_CatalogScope next) {
    final current = _scope;
    return current != null &&
        current.providerId == next.providerId &&
        current.channel == next.channel &&
        current.endpoint == next.endpoint &&
        current.credentialMethod == next.credentialMethod &&
        current.credentialFingerprint == next.credentialFingerprint;
  }

  _CatalogScope _makeScope(
    SpeechConnectionState connection, {
    required String? authIdentity,
  }) {
    final isAntigravity =
        connection.activeCredentialMethod == CredentialMethod.antigravityOauth;
    final endpoint = connection.channel == SpeechChannel.proxy
        ? (connection.proxyRoot ?? '').trim().replaceFirst(RegExp(r'/+$'), '')
        : connection.isAzure
        ? normalizeAzureEndpoint(connection.azureEndpoint)
        : '';
    return (
      providerId: connection.providerId,
      channel: connection.channel,
      endpoint: endpoint,
      credentialMethod: connection.activeCredentialMethod,
      credentialFingerprint: isAntigravity
          ? ''
          : sha256
                .convert(utf8.encode(connection.activeApiKey ?? ''))
                .toString(),
      authIdentity: isAntigravity ? authIdentity : null,
    );
  }

  String _keyFor(_CatalogScope scope) =>
      _scopeKeys.putIfAbsent(scope, () => 'catalog-${_scopeKeys.length + 1}');

  ModelCatalogState _loadingState(String scopeKey) {
    final cached = _cache[scopeKey];
    final current = state.scopeKey == scopeKey ? state : null;
    return ModelCatalogState(
      models: cached?.models ?? current?.models ?? const [],
      source: cached != null
          ? CatalogSource.cache
          : current?.source ?? CatalogSource.none,
      fetchedAt: cached?.fetchedAt ?? current?.fetchedAt,
      isRefreshing: true,
      statusMessage: '正在更新模型目錄',
      scopeKey: scopeKey,
    );
  }

  Future<ModelCatalogState?> _startRefresh(SpeechConnectionState connection) {
    final generation = ++_generation;
    final completer = Completer<ModelCatalogState?>();
    final pending = completer.future;
    _pending = pending;
    state = _loadingState(_keyFor(_scope!));
    unawaited(
      _fetch(connection, generation)
          .then(
            completer.complete,
            onError: (Object error, StackTrace stackTrace) {
              if (!_isCurrent(generation)) {
                completer.complete(null);
                return;
              }
              final result = _fallback(
                const [],
                failure: const CatalogFailure(CatalogFailureKind.unknown),
              );
              state = result;
              completer.complete(result);
            },
          )
          .whenComplete(() {
            if (identical(_pending, pending)) _pending = null;
          }),
    );
    return pending;
  }

  bool _isCurrent(int generation) =>
      ref.mounted && _generation == generation && _connection != null;

  Future<ModelCatalogState?> _fetch(
    SpeechConnectionState connection,
    int generation,
  ) async {
    List<AiModel> bundled = const [];
    try {
      bundled = await _bundledModels(connection);
      if (!_isCurrent(generation)) return null;
      final missing = _missingConfiguration(connection);
      if (missing != null) {
        return _publish(_fallback(bundled, unavailable: missing));
      }
      AntigravityAuthData? auth;
      final isAntigravity =
          connection.activeCredentialMethod ==
          CredentialMethod.antigravityOauth;
      if (isAntigravity) {
        final source = getIt<AntigravityAuthSource>();
        auth = await source.getAuthData();
        if (!_isCurrent(generation)) return null;
        // 外部登入檔可能在兩次更新之間更換帳號；先隔離，再使用快取。
        final identity = auth == null
            ? null
            : source.catalogIdentityFor(auth) ??
                  source.catalogIdentity ??
                  'unidentified-$generation';
        _scope = _makeScope(connection, authIdentity: identity);
        state = _loadingState(_keyFor(_scope!));
        if (auth == null) {
          return _publish(
            _fallback(
              bundled,
              failure: const CatalogFailure(CatalogFailureKind.unauthorized),
            ),
          );
        }
      }
      final CatalogFetchResult result;
      if (connection.channel == SpeechChannel.proxy) {
        result = await getIt<ProxyModelCatalogService>().listModels(
          proxyRoot: connection.proxyRoot!,
          apiKey: connection.proxyApiKey ?? '',
        );
      } else {
        result = await getIt<OfficialModelCatalogService>().listModels(
          providerId: connection.providerId!,
          apiKey: isAntigravity ? null : connection.activeApiKey,
          accessToken: auth?.accessToken,
          projectId: auth?.projectId,
          isAntigravity: isAntigravity,
          azureEndpoint: connection.azureEndpoint,
        );
      }
      if (!_isCurrent(generation)) return null;
      if (!result.isSuccess) {
        return _publish(_fallback(bundled, failure: result.failure));
      }
      final models = List<AiModel>.unmodifiable(
        normalizeCatalogModels(result.models),
      );
      final message = models.isEmpty
          ? '已更新模型目錄，目前沒有可列出的模型'
          : '已更新模型目錄，共 ${models.length} 個模型';
      final snapshot = ModelCatalogState(
        models: models,
        source: CatalogSource.remote,
        fetchedAt: DateTime.now(),
        statusMessage: models.isEmpty ? '目前遠端模型目錄為空' : '',
        refreshMessage: message,
        scopeKey: _keyFor(_scope!),
      );
      _cache[snapshot.scopeKey!] = snapshot;
      return _publish(snapshot);
    } catch (_) {
      if (!_isCurrent(generation)) return null;
      return _publish(
        _fallback(
          bundled,
          failure: const CatalogFailure(CatalogFailureKind.unknown),
        ),
      );
    }
  }

  ModelCatalogState _publish(ModelCatalogState result) {
    state = result;
    return result;
  }

  String? _missingConfiguration(SpeechConnectionState connection) {
    if (connection.providerId == null || connection.providerId!.isEmpty) {
      return '請先選擇 Provider';
    }
    if (connection.channel == SpeechChannel.proxy) {
      return (connection.proxyRoot ?? '').trim().isEmpty
          ? '請先設定 Proxy 根位址'
          : null;
    }
    if (connection.isAzure && (connection.azureEndpoint ?? '').trim().isEmpty) {
      return '請先設定 Azure Service Endpoint';
    }
    if (connection.activeCredentialMethod == null) return '請先選擇使用中憑證';
    if (connection.activeCredentialMethod == CredentialMethod.apiKey &&
        (connection.activeApiKey ?? '').isEmpty) {
      return '請先設定使用中 API Key';
    }
    return null;
  }

  Future<List<AiModel>> _bundledModels(SpeechConnectionState connection) async {
    if (connection.channel == SpeechChannel.proxy) return const [];
    if (connection.activeCredentialMethod ==
        CredentialMethod.antigravityOauth) {
      return OfficialModelCatalogService.antigravityModels;
    }
    final config = await ref.read(providersConfigProvider.future);
    for (final provider in config.speechRecognition) {
      if (provider.id == connection.providerId) return provider.models;
    }
    return const [];
  }

  ModelCatalogState _fallback(
    List<AiModel> bundled, {
    CatalogFailure? failure,
    String? unavailable,
  }) {
    final key = _keyFor(_scope!);
    final cached = _cache[key];
    final models = cached?.models ?? normalizeCatalogModels(bundled);
    final source = cached != null
        ? CatalogSource.cache
        : models.isNotEmpty
        ? CatalogSource.bundled
        : CatalogSource.none;
    final reason = unavailable ?? '更新失敗：${failure?.userMessage ?? '無法取得模型目錄'}';
    final detail = switch (source) {
      CatalogSource.cache => '暫用此通道上次取得的目錄',
      CatalogSource.bundled => '目前顯示內建目錄',
      _ => '仍可沿用上次選擇的模型',
    };
    final message = '$reason；$detail';
    return ModelCatalogState(
      models: List<AiModel>.unmodifiable(models),
      source: source,
      failure: failure,
      fetchedAt: cached?.fetchedAt,
      statusMessage: message,
      refreshMessage: message,
      scopeKey: key,
    );
  }
}
