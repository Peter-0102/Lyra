import '../entities/history_entry.dart';

abstract class HistoryRepository {
  Future<void> recordPlay({
    required String songId,
    required String title,
    required String artist,
    String? filePath,
    int? durationSec,
    required int playedAt,
  });
  Future<List<HistoryEntry>> getHistory({int limit = 50, int offset = 0});
}
