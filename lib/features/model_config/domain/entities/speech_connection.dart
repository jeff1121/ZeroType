enum SpeechChannel { official, proxy }

enum CredentialMethod { apiKey, antigravityOauth }

class SpeechConnectionState {
  const SpeechConnectionState({
    required this.providerId,
    required this.channel,
    required this.officialModelId,
    required this.proxyModelId,
    required this.officialApiKey,
    required this.proxyApiKey,
    required this.proxyRoot,
    required this.officialCredentialMethod,
    required this.antigravityAvailable,
    this.azureEndpoint,
    this.azureApiVersion,
  });

  static const String azureProviderId = 'azure';

  final String? providerId;
  final SpeechChannel channel;
  final String? officialModelId;
  final String? proxyModelId;
  final String? officialApiKey;
  final String? proxyApiKey;
  final String? proxyRoot;
  final CredentialMethod? officialCredentialMethod;
  final bool antigravityAvailable;
  final String? azureEndpoint;
  final String? azureApiVersion;

  bool get isAzure => providerId == azureProviderId;

  /// 各 Provider 允許的通道。Azure 僅官方，其餘為官方 + Proxy。
  static List<SpeechChannel> allowedChannelsFor(String? providerId) {
    if (providerId == azureProviderId) {
      return const [SpeechChannel.official];
    }
    return SpeechChannel.values;
  }

  List<SpeechChannel> get allowedChannels => allowedChannelsFor(providerId);

  String? get modelId =>
      channel == SpeechChannel.official ? officialModelId : proxyModelId;

  String? get activeApiKey =>
      channel == SpeechChannel.official ? officialApiKey : proxyApiKey;

  CredentialMethod? get activeCredentialMethod => channel == SpeechChannel.proxy
      ? CredentialMethod.apiKey
      : officialCredentialMethod;

  bool get isReady {
    if (providerId == null || providerId!.isEmpty) return false;
    if (modelId == null || modelId!.isEmpty) return false;
    if (isAzure) {
      return azureEndpoint != null &&
          azureEndpoint!.isNotEmpty &&
          azureApiVersion != null &&
          azureApiVersion!.isNotEmpty &&
          activeApiKey != null &&
          activeApiKey!.isNotEmpty;
    }
    if (channel == SpeechChannel.proxy &&
        (proxyRoot == null || proxyRoot!.isEmpty)) {
      return false;
    }
    return switch (activeCredentialMethod) {
      CredentialMethod.apiKey =>
        activeApiKey != null && activeApiKey!.isNotEmpty,
      CredentialMethod.antigravityOauth => antigravityAvailable,
      null => false,
    };
  }
}

extension SpeechChannelX on SpeechChannel {
  String get id => switch (this) {
    SpeechChannel.official => 'official',
    SpeechChannel.proxy => 'proxy',
  };

  String get displayName => switch (this) {
    SpeechChannel.official => '官方',
    SpeechChannel.proxy => 'Proxy',
  };

  static SpeechChannel fromId(String? id) => id == SpeechChannel.proxy.id
      ? SpeechChannel.proxy
      : SpeechChannel.official;
}

/// 只保留 Azure origin。使用者若貼上含 `/openai/...` 的完整 URL，避免路徑重複導致 404。
String normalizeAzureEndpoint(String? raw) {
  var value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  value = value.replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}

extension CredentialMethodX on CredentialMethod {
  String get id => switch (this) {
    CredentialMethod.apiKey => 'api_key',
    CredentialMethod.antigravityOauth => 'antigravity_oauth',
  };

  String get displayName => switch (this) {
    CredentialMethod.apiKey => 'API Key',
    CredentialMethod.antigravityOauth => 'Antigravity OAuth',
  };

  static CredentialMethod? fromId(String? id) {
    for (final method in CredentialMethod.values) {
      if (method.id == id) return method;
    }
    return null;
  }
}
