class AiModel {
  const AiModel({required this.id, required this.name});

  final String id;
  final String name;
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
