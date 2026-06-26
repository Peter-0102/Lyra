import 'package:dio/dio.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final Dio _dio;

  HistoryRepositoryImpl(this._dio);

  @override
  Future<void> recordPlay({
    required String songId,
    required String title,
    required String artist,
    String? filePath,
    int? durationSec,
    required int playedAt,
  }) async {
    try {
      await _dio.post('/api/history', data: {
        'songId': songId,
        'title': title,
        'artist': artist,
        'filePath': filePath,
        'durationSec': durationSec,
        'playedAt': playedAt,
      });
    } catch (_) {}
  }

  @override
  Future<List<HistoryEntry>> getHistory({int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get('/api/history', queryParameters: {
        'limit': limit,
        'offset': offset,
      });
      final list = _safeList(response.data);
      return list
          .map((e) {
            if (e is! Map<String, dynamic>) return null;
            try {
              return HistoryEntry.fromJson(e);
            } catch (_) {
              return null;
            }
          })
          .nonNulls
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;
    return [];
  }
}
