import 'package:freezed_annotation/freezed_annotation.dart';

part 'song.freezed.dart';
part 'song.g.dart';

class DurationMillisConverter implements JsonConverter<Duration, Object> {
  const DurationMillisConverter();

  @override
  Duration fromJson(Object json) {
    if (json is int) return Duration(milliseconds: json);
    if (json is double) return Duration(milliseconds: json.toInt());
    if (json is String) {
      final parsed = int.tryParse(json);
      if (parsed != null) return Duration(milliseconds: parsed);
    }
    return Duration.zero;
  }

  @override
  Object toJson(Duration object) => object.inMilliseconds;
}

String _stableHash(String s) {
  int hash = 0;
  for (var i = 0; i < s.length; i++) {
    hash = 31 * hash + s.codeUnitAt(i);
  }
  return hash.toString();
}

String stableIdFromFileName(String fileName) {
  final firstPart = fileName.split('_').first;
  if (firstPart.length == 11 &&
      RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(firstPart)) {
    return firstPart;
  }
  return _stableHash(fileName);
}

String? extractVideoIdFromFileName(String fileName) {
  final firstPart = fileName.split('_').first;
  if (firstPart.length == 11 &&
      RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(firstPart)) {
    return firstPart;
  }
  return null;
}

@freezed
class Song with _$Song {
  const factory Song({
    required String id,
    required String title,
    required String artist,
    required String filePath,
    @DurationMillisConverter() required Duration duration,
    String? thumbnailUrl,
    String? videoId,
  }) = _Song;

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}
