// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'history_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

HistoryEntry _$HistoryEntryFromJson(Map<String, dynamic> json) {
  return _HistoryEntry.fromJson(json);
}

/// @nodoc
mixin _$HistoryEntry {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'song_id')
  String get songId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get artist => throw _privateConstructorUsedError;
  @JsonKey(name: 'file_path')
  String? get filePath => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_sec')
  int? get durationSec => throw _privateConstructorUsedError;
  @JsonKey(name: 'played_at')
  int get playedAt => throw _privateConstructorUsedError;

  /// Serializes this HistoryEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HistoryEntryCopyWith<HistoryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HistoryEntryCopyWith<$Res> {
  factory $HistoryEntryCopyWith(
    HistoryEntry value,
    $Res Function(HistoryEntry) then,
  ) = _$HistoryEntryCopyWithImpl<$Res, HistoryEntry>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'song_id') String songId,
    String title,
    String artist,
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'duration_sec') int? durationSec,
    @JsonKey(name: 'played_at') int playedAt,
  });
}

/// @nodoc
class _$HistoryEntryCopyWithImpl<$Res, $Val extends HistoryEntry>
    implements $HistoryEntryCopyWith<$Res> {
  _$HistoryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? songId = null,
    Object? title = null,
    Object? artist = null,
    Object? filePath = freezed,
    Object? durationSec = freezed,
    Object? playedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            songId: null == songId
                ? _value.songId
                : songId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            artist: null == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String,
            filePath: freezed == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            durationSec: freezed == durationSec
                ? _value.durationSec
                : durationSec // ignore: cast_nullable_to_non_nullable
                      as int?,
            playedAt: null == playedAt
                ? _value.playedAt
                : playedAt // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HistoryEntryImplCopyWith<$Res>
    implements $HistoryEntryCopyWith<$Res> {
  factory _$$HistoryEntryImplCopyWith(
    _$HistoryEntryImpl value,
    $Res Function(_$HistoryEntryImpl) then,
  ) = __$$HistoryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'song_id') String songId,
    String title,
    String artist,
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'duration_sec') int? durationSec,
    @JsonKey(name: 'played_at') int playedAt,
  });
}

/// @nodoc
class __$$HistoryEntryImplCopyWithImpl<$Res>
    extends _$HistoryEntryCopyWithImpl<$Res, _$HistoryEntryImpl>
    implements _$$HistoryEntryImplCopyWith<$Res> {
  __$$HistoryEntryImplCopyWithImpl(
    _$HistoryEntryImpl _value,
    $Res Function(_$HistoryEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? songId = null,
    Object? title = null,
    Object? artist = null,
    Object? filePath = freezed,
    Object? durationSec = freezed,
    Object? playedAt = null,
  }) {
    return _then(
      _$HistoryEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        songId: null == songId
            ? _value.songId
            : songId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: null == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String,
        filePath: freezed == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        durationSec: freezed == durationSec
            ? _value.durationSec
            : durationSec // ignore: cast_nullable_to_non_nullable
                  as int?,
        playedAt: null == playedAt
            ? _value.playedAt
            : playedAt // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HistoryEntryImpl implements _HistoryEntry {
  const _$HistoryEntryImpl({
    required this.id,
    @JsonKey(name: 'song_id') required this.songId,
    required this.title,
    required this.artist,
    @JsonKey(name: 'file_path') this.filePath,
    @JsonKey(name: 'duration_sec') this.durationSec,
    @JsonKey(name: 'played_at') required this.playedAt,
  });

  factory _$HistoryEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$HistoryEntryImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'song_id')
  final String songId;
  @override
  final String title;
  @override
  final String artist;
  @override
  @JsonKey(name: 'file_path')
  final String? filePath;
  @override
  @JsonKey(name: 'duration_sec')
  final int? durationSec;
  @override
  @JsonKey(name: 'played_at')
  final int playedAt;

  @override
  String toString() {
    return 'HistoryEntry(id: $id, songId: $songId, title: $title, artist: $artist, filePath: $filePath, durationSec: $durationSec, playedAt: $playedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HistoryEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.songId, songId) || other.songId == songId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.durationSec, durationSec) ||
                other.durationSec == durationSec) &&
            (identical(other.playedAt, playedAt) ||
                other.playedAt == playedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    songId,
    title,
    artist,
    filePath,
    durationSec,
    playedAt,
  );

  /// Create a copy of HistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HistoryEntryImplCopyWith<_$HistoryEntryImpl> get copyWith =>
      __$$HistoryEntryImplCopyWithImpl<_$HistoryEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HistoryEntryImplToJson(this);
  }
}

abstract class _HistoryEntry implements HistoryEntry {
  const factory _HistoryEntry({
    required final String id,
    @JsonKey(name: 'song_id') required final String songId,
    required final String title,
    required final String artist,
    @JsonKey(name: 'file_path') final String? filePath,
    @JsonKey(name: 'duration_sec') final int? durationSec,
    @JsonKey(name: 'played_at') required final int playedAt,
  }) = _$HistoryEntryImpl;

  factory _HistoryEntry.fromJson(Map<String, dynamic> json) =
      _$HistoryEntryImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'song_id')
  String get songId;
  @override
  String get title;
  @override
  String get artist;
  @override
  @JsonKey(name: 'file_path')
  String? get filePath;
  @override
  @JsonKey(name: 'duration_sec')
  int? get durationSec;
  @override
  @JsonKey(name: 'played_at')
  int get playedAt;

  /// Create a copy of HistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HistoryEntryImplCopyWith<_$HistoryEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
