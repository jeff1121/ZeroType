enum GeminiTranscriptionFailure {
  blocked,
  tokenLimit,
  missingCandidates,
  missingContent,
  thoughtOnly,
  invalidResponse,
  incomplete,
}

/// 僅呈現固定訊息，不包含上游文字、推理、簽章或完整回應。
class GeminiTranscriptionException implements Exception {
  const GeminiTranscriptionException(this.kind);

  final GeminiTranscriptionFailure kind;

  String get userMessage => switch (kind) {
    GeminiTranscriptionFailure.blocked => '模型回應遭封鎖，未取得可用轉寫文字',
    GeminiTranscriptionFailure.tokenLimit => '模型已達輸出長度上限，轉寫尚未完成，請縮短錄音後重試',
    GeminiTranscriptionFailure.missingCandidates => '模型未提供候選回應，請重試',
    GeminiTranscriptionFailure.missingContent => '模型回應沒有可讀取的內容，請重試',
    GeminiTranscriptionFailure.thoughtOnly => '模型未提供可見轉寫文字，請重試',
    GeminiTranscriptionFailure.invalidResponse => '模型回應格式不正確，請重試',
    GeminiTranscriptionFailure.incomplete => '模型未完成轉寫，請重試',
  };

  @override
  String toString() => userMessage;
}

/// 只使用第一個候選的可見文字；part 邊界不是詞或句子的邊界。
String extractGeminiTranscriptionText(dynamic response) {
  if (response is! Map) {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.invalidResponse,
    );
  }
  final dynamic feedback = response['promptFeedback'];
  final dynamic blockReason = feedback is Map ? feedback['blockReason'] : null;
  if (blockReason is String &&
      blockReason.isNotEmpty &&
      blockReason != 'BLOCK_REASON_UNSPECIFIED') {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.blocked,
    );
  }
  final dynamic candidates = response['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.missingCandidates,
    );
  }
  final dynamic candidate = candidates.first;
  if (candidate is! Map) {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.invalidResponse,
    );
  }
  _checkFinishReason(candidate['finishReason']);
  final dynamic content = candidate['content'];
  final dynamic parts = content is Map ? content['parts'] : null;
  if (parts is! List || parts.isEmpty) {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.missingContent,
    );
  }
  final StringBuffer visibleText = StringBuffer();
  bool hasThought = false;
  bool hasVisibleTextPart = false;
  for (final dynamic part in parts) {
    if (part is! Map) continue;
    if (part['thought'] == true) {
      hasThought = true;
      continue;
    }
    final dynamic text = part['text'];
    if (text is String) {
      hasVisibleTextPart = true;
      visibleText.write(text);
    }
  }
  final String result = visibleText.toString().trim();
  if (result.isEmpty && hasThought) {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.thoughtOnly,
    );
  }
  if (!hasVisibleTextPart) {
    throw const GeminiTranscriptionException(
      GeminiTranscriptionFailure.missingContent,
    );
  }
  return result;
}

void _checkFinishReason(dynamic finishReason) {
  final GeminiTranscriptionFailure? failure = switch (finishReason) {
    null || 'STOP' => null,
    'MAX_TOKENS' => GeminiTranscriptionFailure.tokenLimit,
    'SAFETY' ||
    'RECITATION' ||
    'BLOCKLIST' ||
    'PROHIBITED_CONTENT' ||
    'SPII' ||
    'IMAGE_SAFETY' => GeminiTranscriptionFailure.blocked,
    String() => GeminiTranscriptionFailure.incomplete,
    _ => GeminiTranscriptionFailure.invalidResponse,
  };
  if (failure != null) throw GeminiTranscriptionException(failure);
}
