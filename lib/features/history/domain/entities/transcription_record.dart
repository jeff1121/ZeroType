class TranscriptionRecord {
  const TranscriptionRecord({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.provider,
    required this.model,
    this.channel,
    this.credentialMethod,
    this.audioPath,
    this.durationMs,
    this.inputTokens,
    this.outputTokens,
    this.costUsd,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String? audioPath;
  final int? durationMs;
  final String provider;
  final String? channel;
  final String model;
  final String? credentialMethod;
  final int? inputTokens;
  final int? outputTokens;
  final double? costUsd;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'audioPath': audioPath,
    'durationMs': durationMs,
    'provider': provider,
    'channel': channel,
    'model': model,
    'credentialMethod': credentialMethod,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'costUsd': costUsd,
  };

  factory TranscriptionRecord.fromJson(Map<String, dynamic> json) =>
      TranscriptionRecord(
        id: json['id'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        audioPath: json['audioPath'] as String?,
        durationMs: json['durationMs'] as int?,
        provider: json['provider'] as String? ?? '',
        channel: json['channel'] as String?,
        model: json['model'] as String? ?? '',
        credentialMethod: json['credentialMethod'] as String?,
        inputTokens: json['inputTokens'] as int?,
        outputTokens: json['outputTokens'] as int?,
        costUsd: (json['costUsd'] as num?)?.toDouble(),
      );
}
