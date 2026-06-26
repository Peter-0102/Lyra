import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String email,
    required String username,
    String? avatarUrl,
    @Default({}) Map<String, dynamic> settings,
    @UnixTimestampConverter() required DateTime createdAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

class UnixTimestampConverter implements JsonConverter<DateTime, Object> {
  const UnixTimestampConverter();

  @override
  DateTime fromJson(Object json) {
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    if (json is double) return DateTime.fromMillisecondsSinceEpoch(json.toInt());
    if (json is String) {
      final parsed = int.tryParse(json);
      if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
      return DateTime.tryParse(json) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Object toJson(DateTime object) => object.millisecondsSinceEpoch;
}
