import 'dart:async';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class DioHttpClientAdapter extends http.BaseClient {
  final Dio _dio;

  DioHttpClientAdapter({Dio? dio})
      : _dio = (dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 90),
        )));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? body;
    if (request is http.Request) {
      body = request.body;
    }

    final response = await _dio.request<ResponseBody>(
      request.url.toString(),
      data: body,
      options: Options(
        method: request.method,
        headers: request.headers,
        responseType: ResponseType.stream,
        followRedirects: request.followRedirects,
        maxRedirects: request.maxRedirects,
        validateStatus: (_) => true,
      ),
    );

    final responseBody = response.data;
    final headerMap = response.headers.map;
    return http.StreamedResponse(
      responseBody?.stream ?? StreamController<List<int>>().stream,
      response.statusCode ?? 500,
      contentLength: int.tryParse(
        response.headers.value('content-length') ?? '',
      ),
      headers: headerMap.map((k, v) => MapEntry(k, v.join(', '))),
      reasonPhrase: response.statusMessage,
    );
  }

  @override
  void close() => _dio.close();
}
