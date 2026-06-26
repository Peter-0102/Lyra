import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../audio_player/domain/entities/song.dart';

part 'playlist.freezed.dart';
part 'playlist.g.dart';

class _DateTimeConverter implements JsonConverter<DateTime, Object> {
  const _DateTimeConverter();

  @override
  DateTime fromJson(Object json) {
    if (json is String) {
      final parsed = DateTime.tryParse(json);
      if (parsed != null) return parsed;
    }
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    if (json is double) return DateTime.fromMillisecondsSinceEpoch(json.toInt());
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Object toJson(DateTime object) => object.millisecondsSinceEpoch;
}

@freezed
class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String name,
    String? description,
    @Default([]) List<Song> songs,
    @_DateTimeConverter() required DateTime createdAt,
    @_DateTimeConverter() required DateTime updatedAt,
  }) = _Playlist;

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  const Playlist._();

  Duration get totalDuration {
    if (songs.isEmpty) return Duration.zero;
    return songs.fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
  }
}
