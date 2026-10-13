enum ModelSpeechSupport { supported, unsupported, unknown }

class AiModel {
  const AiModel({
    required this.id,
    required this.name,
    this.speechSupport = ModelSpeechSupport.unknown,
    this.supportReason,
    this.supportedMimeTypes,
  });

  final String id;
  final String name;
  final ModelSpeechSupport speechSupport;
  final String? supportReason;
  final Set<String>? supportedMimeTypes;
}

class AiProvider {
  const AiProvider({
    required this.id,
    required this.name,
    required this.models,
  });

  final String id;
  final String name;
  final List<AiModel> models;
}

class ProvidersConfig {
  const ProvidersConfig({required this.speechRecognition});

  final List<AiProvider> speechRecognition;
}
