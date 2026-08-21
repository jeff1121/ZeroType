const Map<String, ({double inputPerM, double outputPerM})> kModelPricing = {
  'gpt-4o-transcribe': (inputPerM: 2.5, outputPerM: 10.0),
  'gemini-2.5-flash': (inputPerM: 1.0, outputPerM: 2.5),
  'gemini-3-flash-preview': (inputPerM: 1.0, outputPerM: 2.5),
  'gemini-3.5-flash-extra-low': (inputPerM: 0.5, outputPerM: 1.5),
  'gemini-3.5-flash-low': (inputPerM: 0.75, outputPerM: 2.0),
  'gemini-3.6-flash-high': (inputPerM: 1.0, outputPerM: 2.5),
  'gemini-3.7-flash-high': (inputPerM: 1.25, outputPerM: 3.0),
  'gemini-3-flash': (inputPerM: 1.0, outputPerM: 2.5),
  'gemini-3-flash-agent': (inputPerM: 1.0, outputPerM: 2.5),
  'gemini-3.1-flash-lite': (inputPerM: 0.5, outputPerM: 1.5),
  'gemini-3.1-flash-image': (inputPerM: 1.0, outputPerM: 2.5),
  'gemini-3.1-pro-low': (inputPerM: 2.0, outputPerM: 5.0),
  'gemini-pro-agent': (inputPerM: 2.5, outputPerM: 6.0),
};

const Map<String, String> kProviderNames = {
  'openai': 'OpenAI',
  'gemini': 'Gemini',
  'azure': 'Azure',
};

const Map<String, String> kModelNames = {
  'gpt-4o-transcribe': 'GPT-4o Transcribe',
  'gemini-2.5-flash': 'Gemini 2.5 Flash',
  'gemini-3-flash-preview': 'Gemini 3 Flash Preview',
  'gemini-3.5-flash-extra-low': 'Gemini 3.5 Flash (Extra Low)',
  'gemini-3.5-flash-low': 'Gemini 3.5 Flash (Low)',
  'gemini-3.6-flash-high': 'Gemini 3.6 Flash (High)',
  'gemini-3.7-flash-high': 'Gemini 3.7 Flash (High)',
  'gemini-3-flash': 'Gemini 3 Flash',
  'gemini-3-flash-agent': 'Gemini 3 Flash (Agent)',
  'gemini-3.1-flash-lite': 'Gemini 3.1 Flash Lite',
  'gemini-3.1-flash-image': 'Gemini 3.1 Flash Image',
  'gemini-3.1-pro-low': 'Gemini 3.1 Pro (Low)',
  'gemini-pro-agent': 'Gemini Pro (Agent)',
};

const Map<String, String> kChannelNames = {'official': '官方', 'proxy': 'Proxy'};

const Map<String, String> kCredentialMethodNames = {
  'api_key': 'API Key',
  'antigravity_oauth': 'Antigravity OAuth',
};

double? calculateCost(String modelId, int? inputTokens, int? outputTokens) {
  final pricing = kModelPricing[modelId];
  if (pricing == null || inputTokens == null || outputTokens == null) {
    return null;
  }
  return (inputTokens * pricing.inputPerM + outputTokens * pricing.outputPerM) /
      1_000_000;
}

String formatCostUsd(double cost) {
  if (cost >= 10) return '\$${cost.toStringAsFixed(2)}';
  return '\$${cost.toStringAsFixed(4)}';
}
