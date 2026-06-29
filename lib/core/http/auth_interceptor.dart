import 'package:dio/dio.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';

class AuthInterceptor extends Interceptor {
  final AuthLocalDataSource _local;
  final AuthRemoteDataSource _remote;
  Dio? _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._local, this._remote);

  void setDio(Dio dio) {
    _dio = dio;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.path.contains('/auth/refresh')) {
      final token = await _local.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _local.getRefreshToken();
      if (refreshToken == null) {
        handler.next(err);
        return;
      }

      final data = await _remote.refreshToken(refreshToken);
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;

      if (newAccess == null || newRefresh == null) {
        await _local.clear();
        handler.next(err);
        return;
      }

      await _local.saveTokens(newAccess, newRefresh);

      if (_dio != null) {
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final response = await _dio!.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _local.clear();
      }
    } catch (_) {
      await _local.clear();
    } finally {
      _isRefreshing = false;
    }

    handler.next(err);
  }
}
