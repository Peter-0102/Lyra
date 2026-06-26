import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_entry.freezed.dart';
part 'history_entry.g.dart';

@freezed
class HistoryEntry with _$HistoryEntry {
  const factory HistoryEntry({
    required String id,
    @JsonKey(name: 'song_id') required String songId,
    required String title,
    required String artist,
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'duration_sec') int? durationSec,
    @JsonKey(name: 'played_at') required int playedAt,
  }) = _HistoryEntry;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$HistoryEntryFromJson(json);
}
