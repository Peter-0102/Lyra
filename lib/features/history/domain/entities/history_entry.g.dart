// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HistoryEntryImpl _$$HistoryEntryImplFromJson(Map<String, dynamic> json) =>
    _$HistoryEntryImpl(
      id: json['id'] as String,
      songId: json['song_id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      filePath: json['file_path'] as String?,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      playedAt: (json['played_at'] as num).toInt(),
    );

Map<String, dynamic> _$$HistoryEntryImplToJson(_$HistoryEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'song_id': instance.songId,
      'title': instance.title,
      'artist': instance.artist,
      'file_path': instance.filePath,
      'duration_sec': instance.durationSec,
      'played_at': instance.playedAt,
    };
