import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:zero_type/features/model_config/domain/entities/model_catalog.dart';

/// 包含建立連線在內的總等待時間有上限；失敗不向上層傳遞敏感回應。
Future<Response<dynamic>> requestModelCatalog({
  required Dio dio,
  required String url,
  required Map<String, String> headers,
  String method = 'GET',
  Object? data,
  Map<String, dynamic>? queryParameters,
}) async {
  final CancelToken cancellation = CancelToken();
  try {
    return await dio
        .request<dynamic>(
          url,
          data: data,
          queryParameters: queryParameters,
          cancelToken: cancellation,
          options: Options(
            method: method,
            headers: headers,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            cancellation.cancel();
            throw const CatalogFailure(CatalogFailureKind.timeout);
          },
        );
  } catch (error) {
    throw classifyCatalogFailure(error);
  }
}

CatalogFailure classifyCatalogFailure(Object error) {
  if (error is CatalogFailure) return error;
  if (error is TimeoutException) {
    return const CatalogFailure(CatalogFailureKind.timeout);
  }
  if (error is FormatException || error is TypeError) {
    return const CatalogFailure(CatalogFailureKind.invalidResponse);
  }
  if (error is SocketException) {
    return const CatalogFailure(CatalogFailureKind.network);
  }
  if (error is! DioException) {
    return const CatalogFailure(CatalogFailureKind.unknown);
  }
  final int? statusCode = error.response?.statusCode;
  if (statusCode != null) {
    final CatalogFailureKind kind = switch (statusCode) {
      401 => CatalogFailureKind.unauthorized,
      403 => CatalogFailureKind.forbidden,
      429 => CatalogFailureKind.rateLimited,
      >= 500 => CatalogFailureKind.server,
      _ => CatalogFailureKind.invalidResponse,
    };
    return CatalogFailure(kind, statusCode: statusCode);
  }
  return CatalogFailure(switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => CatalogFailureKind.timeout,
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate => CatalogFailureKind.network,
    _ when error.error is FormatException || error.error is TypeError =>
      CatalogFailureKind.invalidResponse,
    _ when error.error is SocketException => CatalogFailureKind.network,
    _ => CatalogFailureKind.unknown,
  });
}

bool canTryAnotherCatalogEndpoint(CatalogFailure failure) =>
    failure.kind != CatalogFailureKind.unauthorized &&
    failure.kind != CatalogFailureKind.forbidden &&
    failure.kind != CatalogFailureKind.rateLimited;

List<Map<dynamic, dynamic>> readCatalogList(dynamic data, String field) {
  if (data is! Map || data[field] is! List) {
    throw const CatalogFailure(CatalogFailureKind.invalidResponse);
  }
  final List<dynamic> rows = data[field] as List;
  if (rows.any((dynamic item) => item is! Map)) {
    throw const CatalogFailure(CatalogFailureKind.invalidResponse);
  }
  return rows.cast<Map<dynamic, dynamic>>();
}

String readCatalogId(dynamic value) {
  if (value is! String) {
    throw const CatalogFailure(CatalogFailureKind.invalidResponse);
  }
  return value.trim();
}
