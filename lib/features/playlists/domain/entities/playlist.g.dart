// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlaylistImpl _$$PlaylistImplFromJson(
  Map<String, dynamic> json,
) => _$PlaylistImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  songs:
      (json['songs'] as List<dynamic>?)
          ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: const _DateTimeConverter().fromJson(json['createdAt'] as Object),
  updatedAt: const _DateTimeConverter().fromJson(json['updatedAt'] as Object),
);

Map<String, dynamic> _$$PlaylistImplToJson(_$PlaylistImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'songs': instance.songs,
      'createdAt': const _DateTimeConverter().toJson(instance.createdAt),
      'updatedAt': const _DateTimeConverter().toJson(instance.updatedAt),
    };
