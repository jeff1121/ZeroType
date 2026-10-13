import 'dart:convert';

import 'package:dio/dio.dart';

class CatalogReply {
  const CatalogReply.json(this.data, {this.statusCode = 200})
    : errorType = null;

  const CatalogReply.error(this.errorType) : data = null, statusCode = 0;

  final Object? data;
  final int statusCode;
  final DioExceptionType? errorType;
}

class CatalogTestAdapter implements HttpClientAdapter {
  CatalogTestAdapter(this.replies);

  final List<CatalogReply> replies;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final CatalogReply reply = replies[requests.length];
    requests.add(options);
    if (reply.errorType != null) {
      throw DioException(
        requestOptions: options,
        type: reply.errorType!,
        error: '不應外洩的憑證或回應內容',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(reply.data),
      reply.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
