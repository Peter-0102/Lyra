// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SongImpl _$$SongImplFromJson(Map<String, dynamic> json) => _$SongImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  filePath: json['filePath'] as String,
  duration: const DurationMillisConverter().fromJson(
    json['duration'] as Object,
  ),
  thumbnailUrl: json['thumbnailUrl'] as String?,
  videoId: json['videoId'] as String?,
);

Map<String, dynamic> _$$SongImplToJson(_$SongImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'filePath': instance.filePath,
      'duration': const DurationMillisConverter().toJson(instance.duration),
      'thumbnailUrl': instance.thumbnailUrl,
      'videoId': instance.videoId,
    };
