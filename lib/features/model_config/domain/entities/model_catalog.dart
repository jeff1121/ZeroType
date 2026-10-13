import 'ai_provider.dart';

enum CatalogFailureKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  rateLimited,
  server,
  invalidResponse,
  unknown,
}

/// 只保留可安全呈現的錯誤種類，不攜帶憑證、網址或伺服器回應。
class CatalogFailure implements Exception {
  const CatalogFailure(this.kind, {this.statusCode});

  final CatalogFailureKind kind;
  final int? statusCode;

  String get userMessage => switch (kind) {
    CatalogFailureKind.network => '無法連線至模型目錄，請檢查網路',
    CatalogFailureKind.timeout => '模型目錄查詢逾時，請稍後重試',
    CatalogFailureKind.unauthorized => '模型目錄授權失效，請檢查使用中憑證',
    CatalogFailureKind.forbidden => '使用中憑證沒有模型目錄的存取權限',
    CatalogFailureKind.rateLimited => '模型目錄請求過於頻繁，請稍後重試',
    CatalogFailureKind.server => '模型目錄服務暫時無法使用，請稍後重試',
    CatalogFailureKind.invalidResponse => '模型目錄回應格式不正確',
    CatalogFailureKind.unknown => '無法更新模型目錄，請稍後重試',
  };

  @override
  String toString() => userMessage;
}

class CatalogFetchResult {
  CatalogFetchResult.success(List<AiModel> models)
    : models = List<AiModel>.unmodifiable(models),
      failure = null;

  const CatalogFetchResult.failure(CatalogFailure this.failure)
    : models = const [];

  final List<AiModel> models;
  final CatalogFailure? failure;

  bool get isSuccess => failure == null;
}

/// 同名可以是不同模型；僅按完整 ID 去重，名稱相同時以 ID 穩定排序。
List<AiModel> normalizeCatalogModels(Iterable<AiModel> models) {
  final Map<String, AiModel> unique = <String, AiModel>{};
  for (final AiModel model in models) {
    unique.putIfAbsent(model.id, () => model);
  }
  final List<AiModel> result = unique.values.toList();
  result.sort((AiModel left, AiModel right) {
    final int nameOrder = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    return nameOrder == 0 ? left.id.compareTo(right.id) : nameOrder;
  });
  return List<AiModel>.unmodifiable(result);
}
