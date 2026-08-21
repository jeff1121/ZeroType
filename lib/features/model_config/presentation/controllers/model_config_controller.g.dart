// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_config_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(providersConfig)
final providersConfigProvider = ProvidersConfigProvider._();

final class ProvidersConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProvidersConfig>,
          ProvidersConfig,
          FutureOr<ProvidersConfig>
        >
    with $FutureModifier<ProvidersConfig>, $FutureProvider<ProvidersConfig> {
  ProvidersConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providersConfigProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providersConfigHash();

  @$internal
  @override
  $FutureProviderElement<ProvidersConfig> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProvidersConfig> create(Ref ref) {
    return providersConfig(ref);
  }
}

String _$providersConfigHash() => r'e2ff73813b840311cdc81bbe6411d20be6700000';

@ProviderFor(SpeechProviderController)
final speechProviderControllerProvider = SpeechProviderControllerProvider._();

final class SpeechProviderControllerProvider
    extends
        $AsyncNotifierProvider<
          SpeechProviderController,
          SpeechConnectionState
        > {
  SpeechProviderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speechProviderControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$speechProviderControllerHash();

  @$internal
  @override
  SpeechProviderController create() => SpeechProviderController();
}

String _$speechProviderControllerHash() =>
    r'9340ddf4586d383051d5b84649a6a58af4e3e38a';

abstract class _$SpeechProviderController
    extends $AsyncNotifier<SpeechConnectionState> {
  FutureOr<SpeechConnectionState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<SpeechConnectionState>, SpeechConnectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SpeechConnectionState>,
                SpeechConnectionState
              >,
              AsyncValue<SpeechConnectionState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(proxyModels)
final proxyModelsProvider = ProxyModelsProvider._();

final class ProxyModelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AiModel>>,
          List<AiModel>,
          FutureOr<List<AiModel>>
        >
    with $FutureModifier<List<AiModel>>, $FutureProvider<List<AiModel>> {
  ProxyModelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proxyModelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proxyModelsHash();

  @$internal
  @override
  $FutureProviderElement<List<AiModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AiModel>> create(Ref ref) {
    return proxyModels(ref);
  }
}

String _$proxyModelsHash() => r'18886d28aaf9c87665d9ceb307f04eae4395dea7';

/// 官方通道即時目錄。尚未有可用憑證或查詢失敗時回傳 null，UI 改用內建清單。

@ProviderFor(officialModels)
final officialModelsProvider = OfficialModelsProvider._();

/// 官方通道即時目錄。尚未有可用憑證或查詢失敗時回傳 null，UI 改用內建清單。

final class OfficialModelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AiModel>?>,
          List<AiModel>?,
          FutureOr<List<AiModel>?>
        >
    with $FutureModifier<List<AiModel>?>, $FutureProvider<List<AiModel>?> {
  /// 官方通道即時目錄。尚未有可用憑證或查詢失敗時回傳 null，UI 改用內建清單。
  OfficialModelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'officialModelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$officialModelsHash();

  @$internal
  @override
  $FutureProviderElement<List<AiModel>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AiModel>?> create(Ref ref) {
    return officialModels(ref);
  }
}

String _$officialModelsHash() => r'0325b40765d7c4304aa4ce54678400c7bf8c47e0';
