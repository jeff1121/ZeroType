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
    r'f8c447491c2e33bb8de845bfbdb67e09c8142879';

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
