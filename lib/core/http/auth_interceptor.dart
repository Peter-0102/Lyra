import 'package:dio/dio.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';

class AuthInterceptor extends Interceptor {
  final AuthLocalDataSource _local;
  final AuthRemoteDataSource _remote;
  Dio? _dio;

  AuthInterceptor(this._local, this._remote);

  void setDio(Dio dio) {
    _dio = dio;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _local.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _local.getRefreshToken();
      if (refreshToken != null) {
        try {
          final data = await _remote.refreshToken(refreshToken);
          final newAccess = data['accessToken'] as String;
          final newRefresh = data['refreshToken'] as String;
          await _local.saveTokens(newAccess, newRefresh);

          if (_dio != null) {
            err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
            final response = await _dio!.fetch(err.requestOptions);
            handler.resolve(response);
            return;
          }
        } catch (_) {
          await _local.clear();
        }
      }
    }
    handler.next(err);
  }
}
