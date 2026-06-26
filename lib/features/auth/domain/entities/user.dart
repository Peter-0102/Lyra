import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

int _parseCreatedAt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException(
      'Unexpected createdAt type: ${value.runtimeType} value: $value');
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String username,
    String? avatarUrl,
    @JsonKey(fromJson: _parseCreatedAt) required int createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
